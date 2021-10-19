import
  sequtils, tables, strutils,
  asyncdispatch, options, json
import telebot
import
  telegram/[controller, helper, messages, comfortable],
  # concurrency,
  states, utils

# ROUTER -----------------------------------

const PASS = "1234"

var router = new RouterMap
newRouter(router):
  route(chatid: int, msgtext: string) as "home":
    case msgtext:
    of loginT:
      discard chatid << ("good luck!", noReply)

    of adminT:
      /-> sEnterAdminPass
      discard chatid << (sendAdminPassT, noReply)

    else:
      discard await chatid << (selectOptionsT, notLoggedInReply)

  route(chatid: int, pass: string) as "admin-login":

    case pass:
    of PASS:
      /-> sMenu
      discard chatid << loggedInAsAdminT

    of cancelT:
      /-> sMain
      discard await chatid << returningT
      discard chatid << (menuT, adminReply)

    else:
      discard chatid << passwordIsWrongT

  route(chatid: int) as "verify-user":
    discard

  route(chatid: int, input: string) as "menu":
    case input:
    of addQuizT:
      /-> sAddQuiz
      discard redirect("add-quiz", %[%chatid, %""])
    of findQuizT: 
      /-> sFindQuizMain
      discard redirect("find-quiz", %[%chatid, %""])
    else:
      discard chatid << wrongCommandT

  route(chatid: int, input: string) as "add-quiz":
    template myquiz: untyped = uctx.quizCreation.get

    case uctx.stage:
    of sAddQuiz:
      /-> sAQEnterName
      uctx.quizCreation = some QuizCreate()
      discard chatid << enterQuizNameT

    of sAQEnterName:
      myquiz.name = input
      /-> sAQTime
      discard chatid << enterQuizTimeT

    of sAQTime: # TODO parse time rather than giving a number in seconds
      trySendInvalid:
        myquiz.time = input.parseInt
        /-> sAQgrade
        discard chatid << enterQuizGradeT

    of sAQgrade:
      trySendInvalid:
        myquiz.grade = input.parseInt
        /-> sAQLesson
        discard chatid << enterQuizLessonT

    of sAQLesson:
      myquiz.lesson = input
      /-> sAQchapter
      discard chatid << enterQuizChapterT

    of sAQchapter:
      trySendInvalid:
        myquiz.chapter = input.parseInt
        /-> sAQQuestion
        discard redirect("add-quiestion", %[%chatid, %""])

    else:
      discard chatid << wrongCommandT

  route(chatid: int, input: string) as "add-question":
    let msg = u.message.get
    template allQuestions: untyped = uctx.quizCreation.get.questions

    # FIXME delete quiz from user's object after creating in databse
    case uctx.stage:

    of sAQQuestion:
      if issome uctx.quizCreation:
        # TODO say you can stop adding questions + end key
        discard

      else:
        discard

    of sAQQPic:
      if issome msg.photo:
        let fid = getBiggestPhotoFileId(msg)             # TODO

      /-> sAQQInfo
      discard chatId << enterQuestionInfoT

    of sAQQInfo:
      allquestions[^1].description = input
      /-> sAQQAns
      discard chatId << enterQuestionAnswerT

    of sAQQAns:
      trySendInvalid:
        allquestions[^1].answer = parseint $input[0]
        /-> sAQQuestion
        discard redirect("add-question", %[%chatid, %""])

    else:
      discard

  route(chatid: int, input: string) as "find-quiz":
    template myquery: untyped = uctx.quizQuery.get
    template goBack: untyped = /-> sFindQuizMain

    case input:
    of findQuizT:
      discard # TODO actually send the result + show filters top of result
    of findQuizChangeNameT: /-> sFQname
    of findQuizChangeGradeT: /-> sFQgrade
    of findQuizChangeLessonT: /-> sFQlesson
    of findQuizClearFiltersT: /-> sFindQuizMain

    else:
      case uctx.stage:

      of sfindQuizMain:
        uctx.quizQuery = some QuizQuery()
        discard chatid << findQuizDialogT

      of sFQname:
        myquery.name = some input
        goBack()

      of sFQgrade:
        trySendInvalid:
          myquery.grade = some parseint input
          goBack()

      of sFQlesson:
        myquery.lesson = some input
        goBack()


      else: discard

  route(chatid: int, input: string) as "take-quiz":
    # qet quiz and it's questions from database
    # save them into memory
    # set uctx.quiztaking

    discard

  callbackQuery(chatid: int, buttonText: string) as "select-answer":
    return buttonText

  callbackQuery(chatid: int, buttonText: string) as "select-question":
    return buttonText

  route(chatId: int) as "update-timer":
    discard

  route(chatId: int) as "end-quiz":
    # NOTE: can be called with end of the tiem of cancel by user
    # calulate score
    # save record
    # calulate grade
    # show complete result
    discard


# ------------------------------------------

proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
  var args = newJArray()
  template getuctx: untyped =
    fakeSafety: getOrCreateUser findChatId u

  if u.message.issome:
    let
      uctx = getuctx()
      msg = u.message.get

    args.add %msg.chat.id
    args.add %(
      if issome msg.text: msg.text.get
      else: ""
    )

    let route = case uctx.stage:
      of sMain: "home"
      of sEnterAdminPass: "admin-login"
      of sEnterNumber: "..."
      of sAddQuiz: "add-quiz"
      of sAQQuestion: "add-question"
      else: raise newException(ValueError, "what?")

    fakeSafety:
      discard await trigger(router, route, bot, uctx, u, args)


  elif u.callbackQuery.issome:
    let cq = u.callbackQuery.get

    fakeSafety:
      let res = await trigger(
        router, "select-quiz",
        bot, getuctx, u,
        %*[cq.message.get.chat.id, cq.data.get]
      )

    discard await bot.answerCallbackQuery($cq.id, res)


when isMainModule:
  # addHandler newConsoleLogger(fmtStr = "$levelname, [$time]")

  const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  let bot = newTeleBot API_KEY
  bot.onUpdate dispatcher

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: echo ">>>> " & getCurrentExceptionMsg()
