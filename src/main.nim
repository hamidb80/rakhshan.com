import
  sequtils, tables, strutils, options, json, times, random,
  asyncdispatch, threadpool
import telebot
import
  telegram/[controller, helper, messages, comfortable],
  states, utils, ./math

randomize()
# ROUTER -----------------------------------

var router = new RouterMap
newRouter(router):
  route(chatid: int, msgtext: string) as "home":
    case msgtext:
    of loginT:
      discard chatid << ("good luck!", noReply)

    else:
      discard await chatid << (selectOptionsT, notLoggedInReply)

  route(chatid: int) as "verify-user":
    # send phone number
    # verify code
    # get user info
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

    if input == cancelT:
      discard

    # FIXME delete quiz from user's object after creating in databse
    case uctx.stage:

    of sAQQuestion:
      if allquestions.len == 0:
        asyncCheck chatid << addQuizQuestionFirstT
      else:
        asyncCheck chatid << (addQuizQuestionMoreT, cancelReply)

      allquestions.add QuestionCreate()
      /-> sAQQPic
      asyncCheck chatid << uploadQuizQuestionPicT


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

    else: discard

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

  route(chatid: int, quizid: int) as "take-quiz":
    asyncCheck chatid << (quizWillStartSoonT, cancelReply)

    uctx.record = some QuizTaking()
    template myrecord: untyped = uctx.record.get

    # qet quiz and it's questions from database & save them into memory uctx.record
    # myrecord.quiz =
    # myrecord.questions =
    shuffle myrecord.questions
    myrecord.answersheet = newSeqWith(myrecord.questions.len, 0)
    myrecord.starttime = now()
    myrecord.lastCheckedTime = now()

    myrecord.quizTimeMsgId = (await chatid << timeSerializer myrecord.quiz.time).messageId

    myrecord.questionPicMsgId = (await chatid << "message").messageId
    myrecord.questionInfoMsgId = (await chatid << "message").messageId
    myrecord.answerSheetMsgId = (await chatid << answerSheetSerializer myrecord.answerSheet).messageId


  callbackQuery(chatid: int, buttonText: string) as "quiz-select-answer":
    # change the question to target
    discard

  callbackQuery(chatid: int, buttonText: string) as "quiz-select-question":
    # change the question to target
    discard

  route(chatId: int) as "update-timer":
    let
      record = uctx.record.get
      quiz = record.quiz
      newtime = quiz.time - (now() - record.startTime).inseconds
    discard bot.editMessageText($newtime, $chatid, record.quizTimeMsgId)

  route(chatId: int) as "end-quiz":
    # NOTE: can be called with end of the tiem of cancel by user

    # delete quiz messages
    let r = uctx.record.get
    for msgId in [
      r.quizTimeMsgId,
      r.questionPicMsgId,
      r.questionInfoMsgId,
      r.answerSheetMsgId
    ]:
      asynccheck bot.deleteMessage($chatId, msgid)


    # calulate score
    let percent = getPercent(
      r.answerSheet,
      r.questions.mapIt it.answer.parseInt,
    )

    # save record

    # calulate grade

    # show complete result

    uctx.record = none QuizTaking

# ------------------------------------------

proc checkNofitications(
  pch: ptr Channel[Notification], delay: int,
  bot: TeleBot
) {.async.} =
  while true:
    let (ok, notif) = pch[].tryRecv
    if ok:
      let
        args = %[notif.user_chatid]
        routeName =
          case notif.kind:
          of nkEndQuizTime: "end-quiz"
          of nkUpdateQuizTime: "update-timer"

      asyncCheck router[routeName](
        bot, getOrCreateUser(notif.user_chatid),
        Update(), args)

    await sleepAsync delay

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

  spawn startTimer(100)
  asyncCheck checkNofitications(addr notifier, 100, bot)

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: echo ">>>  " & getCurrentExceptionMsg()
