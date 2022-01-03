import tables, sequtils, strutils, json, options, times, macros
import asyncdispatch, telebot, macroplus
import ../database/models

type
  Stages* = enum
    # basic
    sMain, sSendContact, sEnterMainMenu, sMainMenu
    sFindQuizMain, sFQname, sFQgrade, sFQlesson, sMyRecords, sScroll
    sTakingQuiz, sFindMyRecords

    # admin stuff
    sDeleteQuiz, sDQEnterId, sDQConfirm
    sAddQuiz, sAQName, sAQDesc, sAQTime, sAQGrade, sAQLesson, sAQchapter
    sAQQuestion, sAQQPic, sAQQDesc, sAQQWhy, sAQQAns

type
  SearchFor* = enum
    sfQuiz, sfmyRecords

  QueryPageInfo*[T] = object
    msgid*: Option[int]
    indexRange*: HSlice[int64, int64]
    page*: int
    context*: T

  UserCtx* = ref object
    chatId*: int64
    stage*: Stages

    lastActivity*: DateTime
    membership*: Option[MemberModel]

    quizCreation*: Option[QuizCreate]
    record*: Option[QuizTaking]
    quizQuery*: Option[QuizQuery]
    quizIdToDelete*: Option[int64]
    queryPaging*: Option[QueryPageInfo[SearchFor]]
    firstTime*: bool

  QuizQuery* = object
    name*: Option[string]
    grade*: Option[int]
    lesson*: Option[string]

  QuizTaking* = ref object
    quiz*: QuizModel
    questions*: seq[QuestionModel]
    qi*: int # question index
    answerSheet*: seq[int]

    startTime*: DateTime
    lastCheckedTime*: Datetime
    isReady*: bool
    isEnded*: bool

    lastQuestionPhotoUrl*: string

    quizTimeMsgId*: int
    questionPicMsgId*: int
    questionDescMsgId*: int
    jumpQuestionMsgId*: int
    answerSheetMsgId*: int

  QuizCreate* = ref object
    quiz: QuizModel
    tag: TagModel
    questions*: seq[QuestionModel]

  RouterProc = proc(
        bot: Telebot, uctx: UserCtx,
        u: Update, args: JsonNode): Future[string] {.async.}

  RouterMap* = ref Table[string, RouterProc]


const
  HomeStages* = {sMain, sSendContact} # primary
  DeleteQuiz* = {sDeleteQuiz, sDQEnterId, sDQConfirm}
  AddQuizStages* = {sAddQuiz, sAQName, sAQTime, sAQGrade, sAQLesson, sAQchapter} # admin
  AddQuestionStages* = {sAQQuestion, sAQQPic, sAQQDesc, sAQQWhy, sAQQAns}
  FindQuizStages* = {sFindQuizMain, sFQname, sFQgrade, sFQlesson}
  TakingQuizStages* = {sTakingQuiz}
  RecordStages* = {sFindMyRecords}


# helper

func initQueryPageInfo*[T](context: T): QueryPageInfo[T] =
  result.indexRange = 0'i64 .. int64.high
  result.context = context

proc add(father: NimNode; children: openArray[NimNode]): NimNode =
  for node in children:
    father.add node

  return father

proc extractArgsFromJson(args: openArray[NimNode]): NimNode =
  doassert args.allIt it.kind == nnkExprColonExpr
  result = newStmtList()

  for (index, arg) in args.pairs:
    discard result.add newLetStmt(
      arg[0],
      newcall(
        bindsym "to",
        newNimNode(nnkBracketExpr).add(ident "args", newIntLitNode index),
        arg[1],
    ))


macro initRouter(varName: typed, args: varargs[untyped]): untyped =
  result = newStmtList()
  let body = args[^1]

  for entity in body:
    doAssert:
      entity.kind == nnkInfix and
      entity[InfixIdent].strVal == "as"

    let
      alias = entity[InfixRightSide]
      procBody = entity[^1]
      customArgs = entity[1][1..^1]
      commonArgs = args[0..^2] & @[
          newColonExpr(ident "args", bindsym "JsonNode")]
      extractArgs = extractArgsFromJson(customArgs)

    result.add quote do:
      `varname`[`alias`] = proc(): Future[string] {.async.} =
        `extractArgs`
        `procBody`

    let
      definedProc = result[^1][3]
      paramList = definedProc[RoutineFormalParams]

    case entity[InfixLeftSide][0].strval.normalize:
    of "route": discard
    of "callbackquery": discard
    of "event": discard
    of "command": discard
    else: error "undefined entity"

    discard paramList.add commonArgs.mapIt newIdentDefs(it[0], it[1])

  # echo treeRepr result
  # echo repr result
  return result

template newRouter*(varname, body) =
  initRouter(varname, bot: TeleBot, uctx: UserCtx, u: Update, body)

proc trigger*(
  router: RouterMap, alias: string,
  bot: TeleBot, uctx: UserCtx, u: Update, args: JsonNode = newJArray()
): Future[string] {.async.} =
  doassert args.kind == JArray

  if alias in router:
    return await router[alias](bot, uctx, u, args)

  raise newException(ValueError, "route alias is not defined: " & alias)
