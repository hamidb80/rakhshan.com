import std/[tables, sequtils, strutils, json, options, times, macros, asyncdispatch]
import telebot, macroplus
import database/models, utils

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

  SearchFor* = enum
    sfQuiz, sfmyRecords

  QueryPageInfo*[T] = object
    msgid*: Option[int]
    indexRange*: HSlice[int64, int64]
    page*: int
    context*: T

  UserCtx* = ref object
    chatId*: int64
    firstTime*: bool # is
    stage*: Stages
    lastActivity*: DateTime
    membership*: Option[MemberModel]
    quizCreation*: Option[QuizCreate]
    record*: Option[QuizTaking]
    quizQuery*: Option[QuizQuery]
    quizIdToDelete*: Option[int64]
    queryPaging*: Option[QueryPageInfo[SearchFor]]

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

    questionsOrder: seq[int]
    lastQuestionPhotoUrl*: string

    quizTimeMsgId*: int
    questionPicMsgId*: int
    questionDescMsgId*: int
    jumpQuestionMsgId*: int
    answerSheetMsgId*: int

  QuizCreateFields* = enum
    qzNoField = -1
    qzfName, qzfTime, qzfDescription
    tfGrade, tfLesson, tfChapter
    qfPhotoPath, qfDescription, qfAnswer, qfWhy

  QuestionTracker* = array[qfPhotoPath .. qfWhy, int]

  MessageIdTracker* = object
    quiz*: array[qzfName .. qzfDescription, int]
    tag*: array[tfGrade .. tfChapter, int]
    questions*: seq[QuestionTracker]

  QuizCreate* = ref object
    quiz*: QuizModel
    tag*: TagModel
    questions*: seq[QuestionModel]
    msgIds*: MessageIdTracker

  QCMsgIdSearch* = enum
    qcmsNothing, qcmsQuiz, qcmsTag, qcmsQuestions

  RouteProc* = proc(
    bot: Telebot, u: Update, uctx: UserCtx,
    args: JsonNode): Future[string] {.async.}

  Action* = object
    handler*: RouteProc
    update*: Update
    args*: JsonNode
    chatid*: int64

const
  HomeStages* = {sMain, sSendContact} # primary
  DeleteQuiz* = {sDeleteQuiz, sDQEnterId, sDQConfirm}
  AddQuizStages* = {sAddQuiz, sAQName, sAQDesc, sAQTime, sAQGrade, sAQLesson,
      sAQchapter}                     # admin
  AddQuestionStages* = {sAQQuestion, sAQQPic, sAQQDesc, sAQQWhy, sAQQAns}
  FindQuizStages* = {sFindQuizMain, sFQname, sFQgrade, sFQlesson}
  TakingQuizStages* = {sTakingQuiz}
  RecordStages* = {sFindMyRecords}


func findInEnum[Idx: range](wrapper: array[Idx, int], lookingFor: int): Option[Idx] =
  for i in Idx.low .. Idx.high:
    if wrapper[i] == lookingFor:
      return some i

func first(n: NimNode): NimNode = n[0]

proc reset*(u: UserCtx) =
  u.quizCreation.forget
  u.record.forget
  u.quizQuery.forget
  u.quizIdToDelete.forget
  u.queryPaging.forget

func findEditedMessageIdContext*(
  qc: QuizCreate, msgid: int
): tuple[context: QCMsgIdSearch, index: int, field: QuizCreateFields] =

  if (
    let iqz = qc.msgids.quiz.findInEnum(msgid)
    isSome iqz
  ):
    (qcmsQuiz, 0, iqz.get.ord.QuizCreateFields)

  elif (
    let itg = qc.msgids.tag.findInEnum(msgid)
    isSome itg
  ):
    (qcmsTag, 0, itg.get.ord.QuizCreateFields)

  elif (
    var
      index = NotFound
      field = none range[qfPhotoPath .. qfWhy]

    for i, q in qc.msgids.questions.pairs:
      field = q.findInEnum(msgid)
      if issome field:
        index = i
        break

    index != NotFound
  ):
    (qcmsQuestions, index, field.get.ord.QuizCreateFields)

  else:
    (qcmsNothing, 0, qzNoField)

# helper

func savedMsgIds*(qt: QuizTaking): auto =
  [
    qt.quizTimeMsgId,
    qt.questionPicMsgId,
    qt.questionDescMsgId,
    qt.jumpQuestionMsgId,
    qt.answerSheetMsgId,
  ]

func initQueryPageInfo*[T](context: T): QueryPageInfo[T] =
  result.indexRange = 0'i64 .. int64.high
  result.context = context

proc extractArgsFromJson(args: openArray[NimNode]): NimNode =
  assert args.allIt it.kind == nnkExprColonExpr
  result = newStmtList()

  for (index, arg) in args.pairs:
    discard result.add newLetStmt(
      arg[0],
      newcall(
        bindsym "to",
        newNimNode(nnkBracketExpr).add(ident "args", newIntLitNode index),
        arg[1],
    ))

macro initRouter(varName: untyped, args: varargs[untyped]): untyped =
  result = newStmtList()
  var aliasList: seq[NimNode]
  let
    body = args[^1]
    routerEnum = "RouteEnum".ident

  for entity in body:
    assert:
      entity.kind == nnkInfix and
      entity[InfixIdent].strVal == "as"

    let
      alias = ("re" & entity[InfixRightSide].strVal.normalize.capitalizeAscii).ident
      procBody = entity[^1]
      customArgs = entity[1][1..^1]
      commonArgs = args[0..^2] & @[
          newColonExpr(ident "args", bindsym "JsonNode")]
      extractArgs = extractArgsFromJson(customArgs)

      definedProc = first quote do:
        (proc (): Future[string] {.async.} =
          `extractArgs`
          `procBody`)

      paramList = definedProc[RoutineFormalParams]
      entityKind = entity[InfixLeftSide][0].strval.normalize

    aliasList.add alias

    if entityKind notin ["route", "callbackquery", "event", "command"]:
      error "undefined entity"

    discard paramList.add commonArgs.mapIt newIdentDefs(it[0], it[1])

    result.add quote do:
      `varname`[`alias`] = `definedProc`

  result.insert 0, quote do:
    var `varName`*: array[`routerEnum`, `RouteProc`]

  result.insert 0, newEnum(routerEnum, aliasList, true, false)

  # echo treeRepr result
  # echo repr result
  return result

template newRouter*(varname, body) =
  initRouter(varname, bot: TeleBot, u: Update, uctx: UserCtx, body)

proc trigger*(
  handler: RouteProc, bot: TeleBot, up: Update,
  uctx: UserCtx, args: JsonNode = newJArray()
): Future[string] {.async.} =
  assert args.kind == JArray
  return await handler(bot, up, uctx, args)
