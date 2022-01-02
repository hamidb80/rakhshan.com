import
  sequtils, tables, strutils, options, json, times, random, logging,
  asyncdispatch, threadpool, db_sqlite, os
import telebot
import
  telegram/[controller, helper, messages, comfortable],
  host_api, states, utils, ./mymath, database/[queries]

# prepare ----------------------------------

randomize()
let dbPath = getenv("DB_PATH")

# init -------------------------------------

# router ---

var router = new RouterMap
newRouter router:
  route(chatid: int64, msgtext: string) as "home":
    case msgtext:
      of loginT:
        asyncCheck chatid << (enterPhoneNumberT, sendContactReply)
        /-> sSendContact

      else:
        discard await chatid << (selectOptionsT, notLoggedInReply)

  route(chatid: int64, input: string) as "verify-user":
    try:
      let msg = u.message.get
      if issome msg.contact:
        let
          ct = msg.contact.get
          userInfo = await ct.phoneNumber.getUserInfo # number

        dbworks dbPath:
          db.addMember(chatid, userinfo.display_name,
            (ct.firstname & " " & ct.lastname.get("")),
            ct.phoneNumber, userInfo.is_admin.int)

          uctx.membership = db.getMember chatid

        asyncCheck chatid << (greeting(userinfo.displayName), noReply)
        /-> sEnterMainMenu
        asyncCheck redirect("enter-menu", %*[chatid, ""])

      else:
        asyncCheck chatid << pleaseSendByYourCantactT

    except ValueError:
      asyncCheck chatid << (wrongNumberT, noReply)

  route(chatid: int64) as "enter-menu":
    let keyboardReply =
      if uctx.membership.get.isAdmin == 1:
        adminMenuReply
      else:
        memberMenuReply

    asyncCheck chatid << (chooseOneT, keyboardReply)
    /-> sMainMenu

  route(chatid: int64, input: string) as "menu":
    case input:
    of addQuizT:
      adminRequired:
        /-> sAddQuiz
        asyncCheck redirect("add-quiz", %*[chatid, ""])

    of removeQuizT:
      adminRequired:
        discard

    of findQuizT:
      /-> sFindQuizMain
      uctx.quizQuery = some QuizQuery()
      asynccheck chatid << (findQuizDialogT, quizFilterReply)

    else:
      asyncCheck chatid << wrongCommandT

  route(chatid: int64, input: string) as "add-quiz":
    template myquiz: untyped = uctx.quizCreation.get

    case uctx.stage:
    of sAddQuiz:
      /-> sAQName
      uctx.quizCreation = some QuizCreate()
      asyncCheck chatid << enterQuizNameT

    of sAQName:
      myquiz.name = input
      /-> sAQDesc
      asyncCheck chatid << enterQuizInfoT

    of sAQDesc:
      myquiz.description = input
      /-> sAQTime
      asyncCheck chatid << enterQuizTimeT

    of sAQTime: # TODO parse time rather than giving a number in seconds
      trySendInvalid:
        myquiz.time = input.parseInt
        /-> sAQgrade
        asyncCheck chatid << enterQuizGradeT

    of sAQgrade:
      trySendInvalid:
        myquiz.grade = input.parseInt
        /-> sAQLesson
        asyncCheck chatid << enterQuizLessonT

    of sAQLesson:
      myquiz.lesson = input
      /-> sAQchapter
      asyncCheck chatid << enterQuizChapterT

    of sAQchapter:
      trySendInvalid:
        myquiz.chapter = input.parseInt
        /-> sAQQuestion
        asyncCheck redirect("add-quiestion", %[%chatid, %""])

    else:
      asyncCheck chatid << wrongCommandT

  route(chatid: int64, input: string) as "add-question":
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
        let fid = getBiggestPhotoFileId(msg)

      /-> sAQQInfo
      asyncCheck chatId << enterQuestionInfoT

    of sAQQInfo:
      allquestions[^1].description = input
      /-> sAQQAns
      asyncCheck chatId << enterQuestionAnswerT

    of sAQQAns:
      trySendInvalid:
        allquestions[^1].answer = parseint $input[0]
        /-> sAQQuestion
        asyncCheck redirect("add-question", %[%chatid, %""])

    else: discard

  route(chatid: int64, input: string) as "find-quiz":
    template myquery: untyped = uctx.quizQuery.get
    template goBack: untyped = /-> sFindQuizMain

    case input:
    of findQuizT:
      let
        quizList = dbworksCapture dbpath: findQuizzes(db, myquery, 0, 0)
        str = quizList.map(miniQuizInfo).join "\n"

      if issome myquery.resultMsgId:
        asynccheck (chatid, myquery.resultMsgId.get) <^ str
      else:
        myquery.resultMsgId = some await(chatid << str).messageId

    of findQuizChangeNameT: /-> sFQname
    of findQuizChangeGradeT: /-> sFQgrade
    of findQuizChangeLessonT: /-> sFQlesson
    of findQuizClearFiltersT: /-> sFindQuizMain
    of cancelT:
      uctx.quizQuery = none QuizQuery
      asyncCheck redirect("enter-menu", %*[chatid, ""])

    else:
      case uctx.stage:
      of sfindQuizMain:
        asyncCheck chatid << findQuizDialogT

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

  # TODO edit quiz and question

  command(chatid: int64) as "invalid-command":
    asynccheck chatid << invalidCommandT

  command(chatid: int64, param: string) as "show-quiz":
    let
      quizid = parseint param
      qm = dbworksCapture dbpath: db.getQuizInfo(quizid)

    asynccheck:
      if qm.issome:
        let
          rec = dbworksCapture dbpath: db.getRecordFor(chatid, qm.get.quiz.id)
          text = fullQuizInfo(qm.get, rec)

        if rec.issome:
          chatid << text
        else:
          chatid << (text, genTakeQuizInlineBtn(quizid))

      else:
        chatid << quizNotFoundT

  callbackQuery(chatid: int64) as "delete-quiz":
    discard

  callbackQuery(chatid: int64, param: string) as "take-quiz":
    # TODO gaurd for when is taking quiz
    let
      quizid = parseint param
      quiz = dbworksCapture dbpath: db.getQuizItself(quizid)

    if issome quiz:
      asyncCheck chatid << (quizWillStartSoonT, doingQuizReply)

      uctx.record = some QuizTaking()
      myrecord.quiz = quiz.get
      myrecord.questions = dbworksCapture dbpath: db.getQuestions(quizid)

      # TODO shuffle myrecord.questions

      myrecord.answersheet = newSeqWith(myrecord.questions.len, 0)
      myrecord.starttime = now()
      myrecord.lastCheckedTime = now()

      myrecord.quizTimeMsgId = (await chatid <<
          timeformat myrecord.quiz.time).messageId
      myrecord.qi = 0
      # FIXME send quesition pic
      # myrecord.questionPicMsgId = (await chatid << "message").messageId
      myrecord.questionDescMsgId = (await chatid <<
        (questionSerialize(myrecord.questions[0], 0), answerKeyboard)).messageId

      myrecord.answerSheetMsgId = (await chatid <<
        answerSheetSerialize(myrecord.answerSheet)).messageId

      myrecord.jumpQuestionMsgId = (await chatid <<
        (gotoQuestionT, genQuestionJumpBtns(myrecord.questions.len))).messageId

      myrecord.isReady = true
      /-> sTakingQuiz

    else:
      asyncCheck chatid << quizNotFoundT
      # TODO forward to another route

  callbackQuery(chatid: int64, param: string) as "jump-question":
    if isDoingQuiz:
      let newQuestionIndex = parseint param

      if myrecord.qi != newQuestionIndex:
        myrecord.qi = newQuestionIndex
        asynccheck (chatid, myrecord.questionDescMsgId) <^ (
          questionSerialize(myrecord.questions[newQuestionIndex],
              newQuestionIndex), answerKeyboard)

  callbackQuery(chatid: int64, param: string) as "goto":
    if isDoingQuiz:
      let targetQuestionIndex = 
        if param[0] == '+': 
          min(myrecord.qi + 1, myrecord.questions.high)
        else:
          max(myrecord.qi - 1, 0)

      asyncCheck redirect("jump-question", %*[chatid, $targetQuestionIndex])

  callbackQuery(chatid: int64, param: string) as "select-answer":
    if isDoingQuiz:
      myrecord.answerSheet[myrecord.qi] = parseint param

      asyncCheck (chatid, myrecord.answerSheetMsgId) <^
        answerSheetSerialize(myrecord.answerSheet)

  event(chatId: int64) as "update-timer":
    if isDoingQuiz and myrecord.isReady:
      let
        quiz = myrecord.quiz
        newtime = quiz.time - (now() - myrecord.startTime).inseconds

      if newtime > 0:
        asyncCheck (chatid, myrecord.quizTimeMsgId) <^ timeformat(newtime)

  event(chatId: int64) as "end-quiz":
    if isDoingQuiz:

      # delete quiz messages
      let r = myrecord
      for msgId in [
        r.quizTimeMsgId,
        r.questionPicMsgId,
        r.questionDescMsgId,
        r.jumpQuestionMsgId,
        r.answerSheetMsgId,
      ]:
        asynccheck chatId <! msgid

      let percent = getPercent(
        r.answerSheet,
        r.questions.mapIt it.answer.int)

      # save record
      dbworks dbpath:
        discard db.addRecord(r.quiz.id, chatid, r.answerSheet.join, percent)

      # show complete result
      asyncCheck chatid << recordResultDialog(r.quiz, percent)

      uctx.record = none QuizTaking
      asyncCheck redirect("enter-menu", %*[chatid, ""])

  route(chatid: int64, input: string) as "middle-of-quiz":
    case input
    of endT:
      asyncCheck redirect("end-quiz", %*[chatid, ""])
    of cancelT:
      uctx.record = none QuizTaking
      asyncCheck chatid << quizCancelledT
      asyncCheck redirect("enter-menu", %*[chatid, ""])

    else:
      asyncCheck chatid << invalidInputT

# controllers ---

proc checkNofitications(
  pch: ptr Channel[Notification], delay: int,
  bot: TeleBot
) {.async.} =
  while true:
    await sleepAsync delay

    while true:
      let (ok, notif) = pch[].tryRecv
      if not ok: break

      let
        args = %[notif.user_chatid]
        routeName =
          case notif.kind:
          of nkEndQuizTime: "end-quiz"
          of nkUpdateQuizTime: "update-timer"

      asyncCheck router[routeName](
        bot, getOrCreateUser(notif.user_chatid),
        Update(), args)

proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
  var args = %*[]
  let uctx = castSafety: getOrCreateUser findChatId u

  if uctx.firstTime:
    castSafety:
      let m = dbworksCapture dbPath: getMember(db, u.getchatid)
      if issome m:
        uctx.membership = m
        uctx.stage = sEnterMainMenu

    uctx.firsttime = false

  # TODO catch if error accured and tell the user

  if u.message.issome:
    let
      msg = u.message.get
      text = msg.text.get("")

    if text.startsWith("/") and text.len > 2:
      let
        parameter = text[2..^1]
        route =
          case text[1]:
            of 'q': "show-quiz"
            of 'a': "analyze"
            else: "invalid-command"

      castSafety:
        discard await trigger(router, route, bot, uctx, u, %*[msg.chat.id, parameter])

    # it's a text message
    else:
      args.add %msg.chat.id
      args.add %text

      let route = case uctx.stage:
        of sMain: "home"
        of sSendContact: "verify-user"
        of sAddQuiz: "add-quiz"
        of sAQQuestion: "add-question"
        of sEnterMainMenu: "enter-menu"
        of sMainMenu: "menu"
        of FindQuizStages: "find-quiz"
        of sTakingQuiz: "middle-of-quiz"
        else: "invalid-command"

      castSafety:
        discard await trigger(router, route, bot, uctx, u, args)

  elif u.callbackQuery.issome:
    let
      cq = u.callbackQuery.get
      cmd = cq.data.get("/n0")
      parameter = cmd[2..^1]
      route =
        case cmd[1]:
        of 't': "take-quiz"
        of 'j': "jump-question"
        of 'p': "select-answer"
        of 'g': "goto"
        else: "invalid-command"

    castSafety:
      let res = await trigger(
        router, route,
        bot, uctx, u,
        %*[cq.message.get.chat.id, parameter])

      discard await bot.answerCallbackQuery($cq.id, res)

when isMainModule:
  const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  let bot = newTeleBot API_KEY
  bot.onUpdate dispatcher

  # TODO do some assertions before running like checking the database

  addHandler(newConsoleLogger(fmtStr = "$levelname, [$time] "))

  spawn startTimer(100)
  asyncCheck checkNofitications(addr notifier, 100, bot)

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: echo ">>>  " & getCurrentExceptionMsg()
