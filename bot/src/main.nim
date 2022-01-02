import
  sequtils, tables, strutils, options, json, times, random, logging,
  asyncdispatch, threadpool, db_sqlite, os
import telebot
import
  telegram/[controller, helper, messages, comfortable],
  host_api, states, utils, ./mymath, database/[queries, models]

# prepare ----------------------------------

randomize()

const 
  dbPath = getenv("DB_PATH")
  authorChatId = 101862091

var defaultPhotoUrl = ""

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

  route(chatid: int64) as "verify-user":
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

        discard await chatid << (greeting(userinfo.displayName), noReply)
        asyncCheck redirect("enter-menu", %*[chatid])

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
        /-> sDeleteQuiz
        asyncCheck redirect("delete-quiz", %*[chatid, ""])

    of findQuizT:
      /-> sFindQuizMain
      uctx.quizQuery = some QuizQuery()
      asyncCheck chatid << (findQuizDialogT, quizFilterReply)

    else:
      asyncCheck chatid << wrongCommandT

  route(chatid: int64, input: string) as "add-quiz":
    if input == cancelT:
      uctx.quizCreation = none QuizCreate
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      case uctx.stage:
      of sAddQuiz:
        uctx.quizCreation = some QuizCreate()
        asyncCheck chatid << (enterQuizNameT, cancelReply)
        /-> sAQName

      of sAQName:
        myqc.quiz.name = input
        asyncCheck chatid << enterQuizInfoT
        /-> sAQDesc

      of sAQDesc:
        myqc.quiz.description = input
        /-> sAQTime
        asyncCheck chatid << enterQuizTimeT

      of sAQTime: # TODO parse time rather than giving a number in seconds
        trySendInvalid:
          myqc.quiz.time = input.parseInt
          asyncCheck chatid << enterQuizGradeT
          /-> sAQgrade

      of sAQgrade:
        trySendInvalid:
          myqc.tag.grade = input.parseInt
          asyncCheck chatid << enterQuizLessonT
          /-> sAQLesson

      of sAQLesson:
        myqc.tag.lesson = input
        asyncCheck chatid << enterQuizChapterT
        /-> sAQchapter

      of sAQchapter:
        trySendInvalid:
          myqc.tag.chapter = input.parseInt
          /-> sAQQuestion
          asyncCheck redirect("add-quiestion", %[%chatid, %""])

      else:
        asyncCheck chatid << wrongCommandT

  route(chatid: int64, input: string) as "add-question":
    let msg = u.message.get
    template qs: untyped = uctx.quizCreation.get.questions

    case input
    of endT:
      dbworks dbpath:
        let tg = db.upsertTag(myqc.tag.grade, myqc.tag.lesson, myqc.tag.chapter)
        discard db.addQuiz(
          myqc.quiz.name,
          myqc.quiz.description,
          myqc.quiz.time,
          tg.id,
          myqc.questions)

      asyncCheck chatid << quizAddedDialog(myqc.quiz.name)
      asyncCheck redirect("enter-menu", %*[chatid])
      uctx.quizCreation = none QuizCreate

    of cancelT:
      uctx.quizCreation = none QuizCreate
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      case uctx.stage:
      of sAQQuestion:
        if qs.len == 0:
          asyncCheck chatid << addQuizQuestionFirstT
        else:
          asyncCheck chatid << (addQuizQuestionMoreT, endReply)

        qs.add QuestionModel()
        asyncCheck chatid << (uploadQuizQuestionPicT, withoutPhotoReply)
        /-> sAQQPic

      of sAQQPic:
        template goNext: untyped =
          asyncCheck chatId << enterQuestionInfoT
          /-> sAQQDesc

        if input == withoutPhotoT:
          goNext()

        elif issome msg.photo:
          qs[^1].photo_path = getBiggestPhotoFileId(msg)
          goNext()

        else:
          asyncCheck chatid << uploadQuizQuestionPicT

      of sAQQDesc:
        qs[^1].description = input
        asyncCheck chatId << (enterQuestionAnswerT, answersReply)
        /-> sAQQAns

      of sAQQAns:
        trySendInvalid:
          qs[^1].answer = parseint input[0]
          asyncCheck chatid << enterQuestionWhyY
          /-> sAQQWhy

      of sAQQWhy:
        qs[^1].why = input
        /-> sAQQuestion
        asyncCheck redirect("add-question", %[%chatid, %""])

      else:
        discard

  route(chatid: int64, input: string) as "find-quiz":
    template myquery: untyped = uctx.quizQuery.get
    template goBack: untyped = /-> sFindQuizMain

    case input:
    of findQuizT:
      let
        quizList = dbworksCapture dbpath: findQuizzes(db, myquery, 0, 0)
        str = quizList.map(miniQuizInfo).join "\n"

      if issome myquery.resultMsgId:
        asyncCheck (chatid, myquery.resultMsgId.get) <^ str
      else:
        myquery.resultMsgId = some await(chatid << str).messageId

    of findQuizChangeNameT: /-> sFQname
    of findQuizChangeGradeT: /-> sFQgrade
    of findQuizChangeLessonT: /-> sFQlesson
    of findQuizClearFiltersT: /-> sFindQuizMain
    of cancelT:
      uctx.quizQuery = none QuizQuery
      asyncCheck redirect("enter-menu", %*[chatid])

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

  command(chatid: int64, param: string) as "show-quiz":
    let
      quizid = parseint param
      qm = dbworksCapture dbpath: db.getQuizInfo(quizid)

    asyncCheck:
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

  route(chatid: int64, input: string) as "delete-quiz":
    if input == cancelT:
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      # FIXME put check for every parseint
      case uctx.stage:
      of sDeleteQuiz:
        asyncCheck chatid << (enterQuizIdT, cancelReply)
        /-> sDQEnterId

      of sDQEnterId:
        asyncCheck chatid << (areYouSureT, yesOrNoReply)
        uctx.quizidToDelete = some parseBiggestInt input
        /-> sDQConfirm

      of sDQConfirm:
        asyncCheck:
          if input == yesT:
            dbworks dbpath: db.deleteQuiz(uctx.quizidToDelete.get)
            chatid << quizGotDeletedT
          else:
            chatid << operationCancelledT

        uctx.quizidToDelete = none int64
        asyncCheck redirect("enter-menu", %*[chatid])

      else:
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
      myrecord.qi = 0

      myrecord.quizTimeMsgId = (await chatid <<
          timeformat myrecord.quiz.time).messageId

      myrecord.lastQuestionPhotoUrl = myrecord.questions[0].photo_path or defaultPhotoUrl
      myrecord.questionPicMsgId = (await chatid <@
          myrecord.lastQuestionPhotoUrl).messageId

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
      let
        newQuestionIndex = parseint param
        q = myrecord.questions[newQuestionIndex]

      if myrecord.qi != newQuestionIndex:
        myrecord.qi = newQuestionIndex
        asyncCheck (chatid, myrecord.questionDescMsgId) <^ (
          questionSerialize(q, newQuestionIndex), answerKeyboard)

        # telegram sucks
        let newPhotoUrl = q.photo_path or defaultPhotoUrl
        if newPhotoUrl != myrecord.lastQuestionPhotoUrl:
          myrecord.lastQuestionPhotoUrl = newPhotoUrl
          asyncCheck (chatid, myrecord.questionPicMsgId) <@^ newPhotoUrl

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

  command(chatid: int64, param: string) as "analyze":
    let
      quizid = parseint param
      quiz = dbworksCapture dbpath: db.getQuizItself(quizid)

    if quiz.issome:
      let rec = dbworksCapture dbpath: db.getRecordFor(chatid, quizid)
      if rec.issome:
        let questions = dbworksCapture dbpath: db.getQuestions(quizid)
        for (i, q) in questions.pairs:
          let text = questionAnalyzeDialog(i, q, parseInt rec.get.answer_list[i])

          discard await:
            if q.hasPhoto:
              chatid <@ (q.photo_path, text)
            else:
              chatid << text

      else:
        asyncCheck chatid << youHaventAttendInThisQUizT
    else:
      asyncCheck chatid << quizNotFoundT

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
        asyncCheck chatId <! msgid

      let percent = getPercent(
        r.answerSheet,
        r.questions.mapIt it.answer.int)

      # save record
      dbworks dbpath:
        discard db.addRecord(r.quiz.id, chatid, r.answerSheet.join, percent)

      # show complete result
      asyncCheck chatid << recordResultDialog(r.quiz, percent)

      uctx.record = none QuizTaking
      asyncCheck redirect("enter-menu", %*[chatid])

  route(chatid: int64, input: string) as "middle-of-quiz":
    case input
    of endT:
      asyncCheck redirect("end-quiz", %*[chatid, ""])
    of cancelT:
      uctx.record = none QuizTaking
      asyncCheck chatid << quizCancelledT
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      asyncCheck chatid << invalidInputT

  command(chatid: int64) as "invalid-command":
    asyncCheck chatid << invalidCommandT

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

  # TODO NOT async | do multiplie threads and pass them hits

  if uctx.firstTime:
    castSafety:
      let m = dbworksCapture dbPath: getMember(db, u.getchatid)
      if issome m:
        uctx.membership = m
        uctx.stage = sEnterMainMenu

    uctx.firsttime = false

  # TODO catch if error accured and tell the user and author

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
        of DeleteQuiz: "delete-quiz"
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

  # set default photo
  let m = waitFor authorChatId <@ ("file://" & getCurrentDir() / "assets/no-photo.png")
  defaultPhotoUrl = getBiggestPhotoFileId m

  bot.onUpdate dispatcher
  # TODO do some assertions before running like checking the database

  addHandler(newConsoleLogger(fmtStr = "$levelname, [$time] "))

  spawn startTimer(100)
  asyncCheck checkNofitications(addr notifier, 100, bot)

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: echo ">>>  " & getCurrentExceptionMsg()
