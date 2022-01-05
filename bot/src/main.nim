import
  sequtils, tables, strutils, options, json, times, random,
  asyncdispatch, threadpool, db_sqlite, os, strformat, sugar
import telebot, asyncanything
import
  telegram/[controller, helper, comfortable], messages, forms, concurrency,
  host_api, states, utils, ./mymath, database/[queries, models]

# prepare ----------------------------------

randomize()

const
  dbPath* = getenv("DB_PATH")
  authorChatId* = getenv("AUTHOR_CHAT_ID").parseInt
  pageSize* = getenv("RESULT_PAGE_SIZR", "3").parseint
  tgToken* = getEnv("TG_TOKEN")

var defaultPhotoUrl = ""

# init -------------------------------------

# router ---
var router = new RouterMap
newRouter router:
  route(chatid: int64) as "start":
    if isSome uctx.membership:
      asyncCheck chatid << fmt"{loggedInAsT} '{uctx.membership.get.site_name}'"
    else:
      asyncCheck chatid << firstTimeStartMsgT

    asyncCheck redirect("home", %*[chatid, ""])

  route(chatid: int64, msgtext: string) as "home":
    if isSome uctx.membership:
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      case msgtext:
      of loginT:
        asyncCheck chatid << (enterPhoneNumberT, sendContactReply)
        /-> sSendContact

      else:
        asyncCheck chatid << (selectOptionsT, notLoggedInReply)

  route(chatid: int64) as "verify-user":
    try:
      let msg = u.message.get
      if issome msg.contact:
        let
          ct = msg.contact.get
          userInfo = await ct.phoneNumber.getUserInfo # number

        dbworks dbPath:
          discard |>db.addMemberHandler(chatid, userinfo.display_name,
            (ct.firstname & " " & ct.lastname.get("")),
            ct.phoneNumber, userInfo.is_admin.int, unixNow()).customTryGet

          uctx.membership = db.getMemberHandler(chatid).customTryGet

        asyncCheck chatid << (greeting(userinfo.displayName), noReply)
        asyncCheck redirect("enter-menu", %*[chatid])

      else:
        asyncCheck chatid << pleaseSendByYourCantactT

    except ValueError:
      asyncCheck chatid << (wrongNumberT, noReply)

  route(chatid: int64) as "enter-menu":
    let keyboardReply =
      if uctx.membership.get.isAdmin == 1: adminMenuReply
      else: memberMenuReply

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

    of myRecordsT:
      /-> sMyRecords
      asyncCheck redirect("my-records", %*[chatid])

    else:
      asyncCheck chatid << wrongCommandT

  route(chatid: int64) as "my-records":
    let recs = dbworksCapture dbpath:
      |> db.getMyRecordsHandler(chatid, int64.high, pageSize,
          saLess).customTryGet

    if recs.len == 0:
      asyncCheck chatid << noRecordsAvailableT
      /-> sMainMenu

    else:
      uctx.queryPaging = some initQueryPageInfo(sfQuiz)
      asyncCheck chatid << (yourRecordsT, cancelReply)

      qp.msgid = some (await chatid << (
        recs.map(miniRecordInfo).join "\n\n",
        genQueryPageInlineBtns(0)
      )).messageid

      let minmaxId = [0, recs.high].mapIt(recs[it].record.id)
      qp.indexrange = min(minmaxId) .. max(minmaxId)

      qp.context = sfmyRecords
      /-> sScroll

  route(chatid: int64, input: string) as "add-quiz":
    let msgid = u.message.get.messageId

    if input == cancelT:
      uctx.quizCreation.forget
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      case uctx.stage:
      of sAddQuiz:
        uctx.quizCreation = some QuizCreate()
        asyncCheck chatid << (enterQuizNameT, cancelReply)
        /-> sAQName

      of sAQName:
        qc.quiz.name = input
        qc.msgids.quiz[qzfName] = msgid
        asyncCheck chatid << enterQuizInfoT
        /-> sAQDesc

      of sAQDesc:
        qc.quiz.description = input
        qc.msgids.quiz[qzfDescription] = msgid
        asyncCheck chatid << enterQuizTimeT
        /-> sAQTime

      of sAQTime:
        qc.quiz.time = protectedParseint(input, 60)
        qc.msgids.quiz[qzfTime] = msgid
        asyncCheck chatid << enterQuizGradeT
        /-> sAQgrade

      of sAQgrade:
        qc.tag.grade = protectedParseint(input)
        qc.msgids.tag[tfGrade] = msgid
        asyncCheck chatid << enterQuizLessonT
        /-> sAQLesson

      of sAQLesson:
        qc.tag.lesson = input
        qc.msgids.tag[tfLesson] = msgid
        asyncCheck chatid << enterQuizChapterT
        /-> sAQchapter

      of sAQchapter:
        qc.tag.chapter = protectedParseint(input)
        qc.msgids.tag[tfChapter] = msgid
        /-> sAQQuestion
        asyncCheck redirect("add-question", %*[chatid, ""])

      else:
        asyncCheck chatid << wrongCommandT

  route(chatid: int64, input: string) as "add-question":
    let
      msg = u.message.get
      msgid = msg.messageid

    template qs: untyped = uctx.quizCreation.get.questions
    template lqi: untyped = qc.msgids.questions[^1]

    if input == endT and uctx.stage == sAQQPic:
      dbworks dbpath:
        let tg = |> db.upsertTagHandler(
          qc.tag.grade, qc.tag.lesson, qc.tag.chapter).customTryGet
        discard |>db.addQuizHandler(
          qc.quiz.name,
          qc.quiz.description,
          qc.quiz.time,
          tg.id,
          unixNow(),
          qc.questions).customTryGet

      asyncCheck chatid << quizAddedDialog(qc.quiz.name)
      asyncCheck redirect("enter-menu", %*[chatid])
      uctx.quizCreation.forget

    else:
      case uctx.stage:
      of sAQQuestion:
        if qs.len == 0:
          asyncCheck chatid << (addFirstQuizQuestionT, withoutPhotoReply)
        else:
          asyncCheck chatid << (addQuizQuestionMoreT, addingMoreQuestionsReply)

        asyncCheck chatid << uploadQuizQuestionPicT
        /-> sAQQPic

      of sAQQPic:
        template init: untyped =
          qs.add QuestionModel()
          qc.msgids.questions.add [msgid, 0, 0, 0].QuestionTracker

        template goNext: untyped =
          asyncCheck chatId << (enterQuestionInfoT, noReply)
          /-> sAQQDesc

        if input == withoutPhotoT:
          init()
          goNext()

        elif issome msg.photo:
          init()
          qs[^1].photo_path = getBiggestPhotoFileId(msg)
          goNext()

        else:
          asyncCheck chatid << uploadQuizQuestionPicT

      of sAQQDesc:
        qs[^1].description = input
        lqi[qfDescription] = msgid
        asyncCheck chatId << (enterQuestionAnswerT, answersReply)
        /-> sAQQAns

      of sAQQAns:
        qs[^1].answer = protectedParseint(input, 1, 4)
        lqi[qfAnswer] = msgid
        asyncCheck chatid << (enterQuestionWhyY, noReply)
        /-> sAQQWhy

      of sAQQWhy:
        qs[^1].why = input
        lqi[qfWhy] = msgid
        /-> sAQQuestion
        asyncCheck redirect("add-question", %*[chatid, ""])

      else: discard

  route(chatid: int64, input: string) as "find-quiz":
    template goBack: untyped = /-> sFindQuizMain

    case input:
    # FIXME say something
    of findQuizChangeNameT:
      /-> sFQname

    of findQuizChangeGradeT:
      /-> sFQgrade

    of findQuizChangeLessonT:
      /-> sFQlesson

    of findQuizClearFiltersT:
      /-> sFindQuizMain

    of showResultsT:
      asyncCheck chatid << $qq

      let quizzes = dbworksCapture dbpath:
        |> db.findQuizzesHandler(qq, int64.high, pageSize, saLess).customTryGet

      if quizzes.len == 0:
        asyncCheck chatid << noResultFoundT

      else:
        asyncCheck chatid << (yourSearchResultT, cancelReply)
        uctx.queryPaging = some initQueryPageInfo(sfQuiz)

        qp.msgid = some (await chatid << (
          quizzes.map(miniQuizInfo).join "\n",
          genQueryPageInlineBtns(0)
        )).messageid

        let minmaxId = [0, quizzes.high].mapIt(quizzes[it].quiz.id)
        qp.indexrange = min(minmaxId) .. max(minmaxId)
        qp.context = sfQuiz
        /-> sScroll

    of cancelT:
      uctx.quizQuery.forget
      uctx.queryPaging.forget
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      case uctx.stage:
      of sfindQuizMain:
        asyncCheck chatid << findQuizDialogT

      of sFQname:
        qq.name = some input
        goBack()

      of sFQgrade:
        qq.grade = some protectedParseint input
        goBack()

      of sFQlesson:
        qq.lesson = some input
        goBack()

      else: discard

  route(chatid: int64, msgid: int) as "edit-quiz-creation":
    template msg: untyped = u.editedmessage.get
    template input: untyped = msg.text.get("")
    template qi: untyped = qc.questions[index]

    let (ctx, index, field) = findEditedMessageIdContext(qc, msgid)
    case ctx:
    of qcmsQuiz, qcmsTag:
      case field:
      of qzfName: qc.quiz.name = input
      of qzfTime: qc.quiz.time = protectedParseint input
      of qzfDescription: qc.quiz.description = input
      of tfGrade: qc.tag.grade = protectedParseint input
      of tfLesson: qc.tag.lesson = input
      of tfChapter: qc.tag.chapter = protectedParseint input
      else: discard
      asyncCheck chatid << fmt"{fieldT} '{field}' {changedT}"

    of qcmsQuestions:
      case field:
      of qfPhotoPath:
        qi.photo_path =
          if issome msg.photo: getBiggestPhotoFileId msg
          else: ""

      of qfDescription: qi.description = input
      of qfWhy: qi.why = input
      of qfAnswer: qi.answer = protectedParseint(input, 1, 4)
      else: discard
      asyncCheck chatid << fmt"{fieldT} '{field}' {fromQuestionNumberT} {(index+1)} {changedT}"

    of qcmsNothing:
      asyncCheck chatid << nothingHasChangedT

  callbackQuery(chatid: int64, msgId: int, param: string) as "scroll":
    if issome uctx.queryPaging:
      if qp.msgid.get == msgid:
        let
          btnDir =
            if param == "+": saMore
            else: saLess
          dir = ~btnDir

        if not (qp.page == 0 and btnDir == saLess):

          case qp.context:
          of sfQuiz:
            let quizzes = dbworksCapture dbpath:
              |> db.findQuizzesHandler(qq, qp.indexRange[dir], pageSize,
                  dir).customTryGet

            if quizzes.len != 0:
              let qi = [quizzes[0].quiz.id, quizzes[^1].quiz.id]
              qp.indexRange = min(qi) .. max(qi)
              qp.page.inc btnDir.toInt

              asyncCheck (chatid, msgid) <^ (
                quizzes.map(miniQuizInfo).join "\n",
                genQueryPageInlineBtns(qp.page))

            else:
              result = itsTheEndT

          of sfmyRecords:
            let recs = dbworksCapture dbpath:
              |> db.getMyRecordsHandler(chatid, qp.indexRange[dir],
                  pageSize, dir).customTryGet

            if recs.len != 0:
              let ri = [recs[0].record.id, recs[^1].record.id]
              qp.indexRange = min(ri) .. max(ri)
              qp.page.inc btnDir.toInt

              asyncCheck (chatid, msgid) <^ (
                recs.map(miniRecordInfo).join "\n\n",
                genQueryPageInlineBtns(qp.page))

            else:
              result = itsTheEndT
        else:
          result = itsTheStartT

      else: result = messageExpiredT
    else: result = wrongCommandT

  route(chatid: int64, input: string) as "middle-of-scroll":
    if input == cancelT:
      asyncCheck redirect("enter-menu", %*[chatid])

  command(chatid: int64, param: string) as "show-quiz":
    let
      quizid = parseint param
      qm = dbworksCapture dbpath: |> db.getQuizInfoHandler(quizid).customTryGet

    asyncCheck:
      if qm.issome:
        let
          rec = dbworksCapture dbpath: |> db.getRecordForHandler(chatid,
              qm.get.quiz.id).customTryGet
          text = fullQuizInfo(qm.get, rec)

        if rec.issome:
          chatid << text
        else:
          chatid << (text, genTakeQuizInlineBtn(quizid))

      else:
        chatid << quizNotFoundT

  command(chatid: int64, param: string) as "get-rank":
    let
      quizid = parseint param
      rank = dbworksCapture dbpath: |> db.getRankHandler(chatid,
          quizid).customTryGet

    asyncCheck chatid << (
      if isSome rank: fmt"{yourRankInThisQuizYetT}: {rank.get}"
      else: youHaventAttendInThisQUizT)

  route(chatid: int64, input: string) as "delete-quiz":
    if input == cancelT:
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
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
            dbworks dbpath:
              discard |>db.deleteQuizHandler(
                  uctx.quizidToDelete.get).customTryGet

            chatid << quizGotDeletedT
          else:
            chatid << operationCancelledT

        uctx.quizidToDelete.forget
        asyncCheck redirect("enter-menu", %*[chatid])

      else:
        discard

  callbackQuery(chatid: int64, _: int, param: string) as "take-quiz":
    # TODO gaurd for when is taking quiz
    if not isDoingQuiz:
      let
        quizid = parseint param
        quiz = dbworksCapture dbpath: |> db.getQuizItselfHandler(
            quizid).customTryGet

      if issome quiz:
        if not dbpath.dbworksCapture( |> db.isRecordExistsForHandler(chatid,
            quizid).customTryGet):
          asyncCheck chatid << quizWillStartSoonT

          uctx.record = some QuizTaking()
          myrecord.quiz = quiz.get
          myrecord.questions = dbworksCapture dbpath: |> db.getQuestionsHandler(
              quizid).customTryGet

          myrecord.questionsOrder = toseq(0 .. myrecord.questions.high).dup(shuffle)
          let fqi = myrecord.questionsOrder[0] # first question index

          myrecord.answersheet = newSeqWith(myrecord.questions.len, 0)
          myrecord.starttime = now()
          myrecord.lastCheckedTime = now()
          myrecord.qi = 0

          myrecord.quizTimeMsgId = (await chatid <<
              timeformat myrecord.quiz.time).messageId

          asyncCheck bot.pinChatMessage($chatid, myrecord.quizTimeMsgId)

          myrecord.lastQuestionPhotoUrl = myrecord.questions[fqi].photo_path or defaultPhotoUrl
          myrecord.questionPicMsgId = (await chatid <@
              myrecord.lastQuestionPhotoUrl).messageId

          myrecord.questionDescMsgId = (await chatid <<
            (questionSerialize(myrecord.questions[fqi], 0),
                answerKeyboard)).messageId

          myrecord.answerSheetMsgId = (await chatid <<
            answerSheetSerialize(myrecord.answerSheet)).messageId

          myrecord.jumpQuestionMsgId = (await chatid <<
            (gotoQuestionT, genQuestionJumpBtns(
                myrecord.questions.len))).messageId

          asyncCheck chatid << (quizStartedT, doingQuizReply)

          myrecord.isReady = true
          /-> sTakingQuiz

        else:
          asyncCheck chatid << youHaveTakenTheQuizBeforeT

      else:
        asyncCheck chatid << quizNotFoundT

    else:
      result = youAreTakingQuizT

  callbackQuery(chatid: int64, msgid: int, param: string) as "jump-question":
    if isDoingQuiz and (msgid in myrecord.savedMsgIds):
      let
        newQuestionIndex = parseint param
        q = myrecord.questions[myrecord.questionsOrder[newQuestionIndex]]

      if myrecord.qi != newQuestionIndex:
        myrecord.qi = newQuestionIndex
        asyncCheck (chatid, myrecord.questionDescMsgId) <^ (
          questionSerialize(q, newQuestionIndex), answerKeyboard)

        # telegram sucks
        let newPhotoUrl = q.photo_path or defaultPhotoUrl
        if newPhotoUrl != myrecord.lastQuestionPhotoUrl:
          myrecord.lastQuestionPhotoUrl = newPhotoUrl
          asyncCheck (chatid, myrecord.questionPicMsgId) <@^ newPhotoUrl

    else:
      result = messageExpiredT

  callbackQuery(chatid: int64, msgid: int, param: string) as "goto":
    if isDoingQuiz:
      let targetQuestionIndex =
        if param[0] == '+':
          min(myrecord.qi + 1, myrecord.questions.high)
        else:
          max(myrecord.qi - 1, 0)

      result = await redirect(
        "jump-question", %*[chatid, msgid, $targetQuestionIndex])

  callbackQuery(chatid: int64, msgid: int, param: string) as "select-answer":
    if isDoingQuiz:
      if msgid in myrecord.savedMsgIds:
        myrecord.answerSheet[myrecord.qi] = parseint param

        asyncCheck (chatid, myrecord.answerSheetMsgId) <^
          answerSheetSerialize(myrecord.answerSheet)

      else: result = messageExpiredT
    else: result = messageExpiredT

  command(chatid: int64, param: string) as "analyze":
    let
      quizid = parseint param
      quiz = dbworksCapture dbpath: |> db.getQuizItselfHandler(
          quizid).customTryGet

    if quiz.issome:
      let rec = dbworksCapture dbpath: |> db.getRecordForHandler(chatid,
          quizid).customTryGet
      if rec.issome:
        let
          questions = dbworksCapture dbpath: |> db.getQuestionsHandler(
              quizid).customTryGet
          qoi = rec.get.questionsOrder.parseJson.to(seq[int]) # question order index

        for i in 0 .. questions.high:
          let
            yourIndex = qoi[i]
            q = questions[yourIndex]
            text = questionAnalyzeDialog(i, q, parseint rec.get.answer_list[i])

          discard await:
            if q.hasPhoto: chatid <@ (q.photo_path, text)
            else: chatid << text

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
      for msgId in r.savedMsgIds:
        asyncCheck chatId <! msgid

      let percent = getPercent(
        r.answerSheet, r.questionsOrder.mapIt(r.questions[it].answer.int))

      # save record
      dbworks dbpath:
        discard |>db.addRecordHandler(r.quiz.id, chatid, r.answerSheet.join,
            ($r.questionsOrder).substr(1), percent, unixNow()).customTryGet

      # show complete result
      asyncCheck chatid << recordResultDialog(r.quiz, percent)

      uctx.record.forget
      asyncCheck redirect("enter-menu", %*[chatid])

  route(chatid: int64, input: string) as "middle-of-quiz":
    case input
    of endT:
      asyncCheck redirect("end-quiz", %*[chatid, ""])
    of cancelT:
      uctx.record.forget
      asyncCheck chatid << quizCancelledT
      asyncCheck redirect("enter-menu", %*[chatid])

    else:
      asyncCheck chatid << invalidInputT

  command(chatid: int64) as "invalid-command":
    asyncCheck chatid << wrongCommandT

  callbackQuery(_: int) as "dont-care": discard

# controllers ---
proc eventHandler(
  route: string, bot: TeleBot, uctx: UserCtx, u: Update, chatid: int64
) {.async.} =
  try: discard await trigger(router, route, bot, uctx, u, %[chatid])
  except DbError: chatid !! databaseErrorT
  except RuntimeError: chatid !! runtimeErrorT
  except Exception: chatid !! someErrorT

proc checkNofitications(
  pch: ptr Channel[Notification], delay: int, bot: TeleBot
) {.async.} =
  while true:
    await sleepAsync delay

    while true:
      let (ok, notif) = pch[].tryRecv
      if not ok: break

      let routeName = case notif.kind:
        of nkEndQuizTime: "end-quiz"
        of nkUpdateQuizTime: "update-timer"

      asyncCheck eventHandler(routeName, bot,
        getOrCreateUser(notif.user_chatid), Update(), notif.user_chatid)

proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
  let
    chatid = findChatId u
    uctx = castSafety: getOrCreateUser chatid

  var args = %*[chatid]

  if uctx.firstTime:
    castSafety:
      let m = dbworksCapture dbPath:
        |> getMemberHandler(db, u.getchatid).customTryGet

      if issome m:
        uctx.membership = m

      asyncCheck trigger(router, "start", bot, uctx, u, args)
    uctx.firsttime = false

  else:
    debugEcho ">> ", uctx.stage, " || ", chatid

    try:
      if u.message.issome:
        let
          msg = u.message.get
          text = msg.text.get("")

        if text.startsWith("/") and text.len > 2:
          let
            parameter = text[2..^1]
            route = case text[1]:
              of 's': "start"
              of 'w': "where-am-i"
              of 'q': "show-quiz"
              of 'a': "analyze"
              of 'r': "get-rank"
              else: "invalid-command"

          args.add %parameter
          castSafety:
            discard await trigger(router, route, bot, uctx, u, args)

        # it's a text message
        else:
          args.add %text

          let route = case uctx.stage:
            of sMain: "home"
            of sSendContact: "verify-user"
            of AddQuizStages: "add-quiz"
            of AddQuestionStages: "add-question"
            of sEnterMainMenu: "enter-menu"
            of sMainMenu: "menu"
            of FindQuizStages: "find-quiz"
            of DeleteQuiz: "delete-quiz"
            of sTakingQuiz: "middle-of-quiz"
            of sScroll: "middle-of-scroll"
            else: "invalid-command"

          castSafety:
            discard await trigger(router, route, bot, uctx, u, args)

      elif u.editedMessage.issome:
        args.add %u.editedMessage.get.messageId

        let route =
          case uctx.stage:
          of AddQuizStages, AddQuestionStages: "edit-quiz-creation"
          else: raise newException(ValueError,
              "cant edit message when stage is: " & $uctx.stage)

        castSafety:
          asyncCheck trigger(router, route, bot, uctx, u, args)

      elif u.callbackQuery.issome:
        let
          cq = u.callbackQuery.get
          cmd = cq.data.get("/d")
          parameter = cmd[2..^1]
          route = case cmd[1]:
            of 't': "take-quiz"
            of 'j': "jump-question"
            of 'p': "select-answer"
            of 'g': "goto"
            of 'm': "scroll"
            of 'd': "dont-care"
            else: "invalid-command"

        castSafety:
          let res = await trigger(
            router, route,
            bot, uctx, u,
            %*[cq.message.get.chat.id, cq.message.get.messageId, parameter])

          asyncCheck bot.answerCallbackQuery($cq.id, res)

    except DbError: chatid !! databaseErrorT
    except RuntimeError: chatid !! runtimeErrorT
    except FValueError: asyncCheck chatid << invalidInputT
    except FmRangeError: asyncCheck chatid << rangeErrorT
    except Exception: chatid !! someErrorT

when isMainModule:
  let bot = newTeleBot tgToken

  # set default photo
  let m = waitFor authorChatId <@ ("file://" & getCurrentDir() / "assets/no-photo.png")
  defaultPhotoUrl = getBiggestPhotoFileId m

  bot.onUpdate dispatcher

  spawn startTimer(100)
  asyncCheck checkNofitications(addr notifier, 100, bot)

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: echo ">>>  " & getCurrentExceptionMsg()
