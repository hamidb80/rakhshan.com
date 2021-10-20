import tables, sequtils, strutils, json, options, times
import macros except params
import
  asyncdispatch, telebot,
  macroplus

type
  Stages* = enum
    sMain, sEnterNumber, sEnterAdminPass, sMenu # primary
    sAddQuiz, sAQEnterName, sAQTime, sAQGrade, sAQLesson, sAQchapter # admin
    sAQQuestion, sAQQPic, sAQQInfo, sAQQAns
    sFindQuizMain, sFQname, sFQgrade, sFQlesson
    sTakingQuiz
    sFindMyRecords


  UserCtx* = ref object
    chatId*: int64
    stage*: Stages

    name*: string
    isAdmin*: bool
    lastActivity: DateTime

    quizCreation*: Option[QuizCreate]
    quizTaking*: Option[QuizTaking]
    quizQuery*: Option[QuizQuery]

  QuizQuery* = object
    name*: Option[string]
    grade*: Option[int]
    lesson*: Option[string]

  QuizTaking* = object
    quizId: int
    currentQuestionIndex: int
    questionsOrder*: seq[int]
    answerSheet*: seq[int]

    # startTime

    quizTimeMsgId*: int
    questionPicMsgId*: int
    questionInfoMsgId*: int
    answerSheetMsgId*: int

  QuizCreate* = object
    name*: string
    time*: int
    # part info
    grade*: int
    lesson*: string
    chapter*: int
    # ---
    questions*: seq[QuestionCreate]

  QuestionCreate* = object
    description*: string
    photo_path*: string
    answer*: int


  RouterProc = proc(bot: Telebot, uctx: UserCtx, u: Update,
      args: JsonNode): Future[string] {.async.}
  RouterMap* = ref Table[string, RouterProc]


# helper
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
      commonArgs = args[0..^2] & @[newColonExpr(ident "args",
          bindsym "JsonNode")]
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

  raise newException(ValueError, "route alias is not defined")
