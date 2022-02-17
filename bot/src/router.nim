import
  std/[sequtils, tables, strutils, options, json, times, random, algorithm,
  asyncdispatch, db_sqlite, strformat, sugar]
import telebot
import
  controller, comfortable,
  messages, forms, settings,
  host_api, utils, database/[queries, models]

# TODO send notification to admin when a new form submitted
# just notify without details ... to all of the admins

# TODO add /backup (using sqlite backup) every 24 hours and send in PV
# TODO improve help
# TODO test form with arbitary message types like photo or audio

newRouter router:
  command(chatid: int64) as "help":
    asyncCheck chatid << [
      fmt"{bold helpT}: {'\n'}",
      fmt"{bold gradesT} {italic positiveIntegerT} {areT}",
      fmt"{bold chaptersT} {italic positiveIntegerT} {areT}",
      fmt"{bold minQuizTimeT} {underline($minQuizTime & secondT)} {isT}",
    ].join "\n"

  command(chatid: int64) as "start":
    if isSome uctx.membership:
      asyncCheck chatid << fmt"{loggedInAsT} '{uctx.membership.get.site_name}'"

    else:
      asyncCheck chatid << firstTimeStartMsgT

    asyncCheck redirect(reEnterhome, args)

  route(chatid: int64, input: string) as "home":
    template getPlans(planKind): untyped =
      let
        plans = ++ db.getPlansTitles planKind
        kr = newReplyKeyboardMarkupEveryRow(plans & @[cancelT], 2)

      /-> sspShowPlan
      asyncCheck chatid << (chooseOneT, kr)

    case input:
    of knowUsT:
      let p = ++db.getPost(pokIntroduction)

      if isSome p:
        asyncCheck bot.sendVideo(chatid, p.get.videoPath, caption = $p.get)
      else:
        asyncCheck chatid << postNotFoundT

    of knowConsultingPlansT:
      getPlans pkConsulting

    of knowEducationalPlansT:
      getPlans pkEducational

    of registerInVaiousPlansT:
      uctx.form = some FormModel(chatId: chatid,
        kind: fkRegisterInPlans.ord)

      /-> sfPlan
      asyncCheck redirect(reFillform, %*[chatid, ""])

    of reportProblemsT:
      uctx.form = some FormModel(chatId: chatid,
        kind: fkReportProblem.ord)

      /-> sfReportProblem
      asyncCheck redirect(reFillform, %*[chatid, ""])

    of loginT:
      asyncCheck chatid << (enterPhoneNumberT, sendContactReply)
      /-> sSendContact

    of quizT:
      if issome uctx.membership:
        asyncCheck redirect(reQuizmenu, %*[chatid, ""])

      else:
        asyncCheck chatid << youMustLoginToUseThisSection

    of adminPanelT:
      if isAdmin uctx:
        asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

    else:
      asyncCheck chatid << invalidInputT

  route(chatid: int64) as "enter_home":
    let keyboardReply =
      if isAdmin uctx: adminReply
      elif issome uctx.membership: memberReply
      else: notLoggedInReply

    asyncCheck chatid << (chooseOneT, keyboardReply)
    /-> sMainMenu

  route(chatid: int64, input: string) as "see_plans":
    if input == cancelT:
      asyncCheck redirect(reEnterhome, args)

    else:
      let p = ++db.getPlan(input)
      if isSome p:
        asyncCheck bot.sendVideo(chatid, p.get.videopath,
            caption = p.get.description)

      else:
        asyncCheck chatid << invalidInputT

  route(chatid: int64, input: string) as "fill_form":
    if input == cancelT:
      forget uctx.form
      asyncCheck redirect(reEnterhome, %*[chatid])

    else:
      template gotoNumber: untyped =
        asyncCheck chatid << (enterPhoneNumberT, noReply)
        /-> sfNumber

      case uctx.stage:
      of sfPlan:
        asyncCheck chatid << (selectPlanKindT, selectPlanKindsReply)
        /-> sfSelectPlanType

      of sfSelectPlanType:
        template job(planKind): untyped =
          asyncCheck chatid << (chooseOneT,
            toRKeyboard( ++db.getPlansTitles(planKind) & @[cancelT]))

          /-> sfSelectPlan

        case input:
        of $pkConsulting: job pkConsulting
        of $pkEducational: job pkEducational
        else: asyncCheck chatid << invalidInputT

      of sfSelectPlan:
        if ++db.isPlanExists(input):
          asyncCheck chatid << (enterFullNameT, noReply)
          /-> sfName

        else:
          asyncCheck chatid << invalidInputT

      of sfReportProblem:
        asyncCheck chatid << (enterFullNameT, noReply)
        /-> sfName

      of sfName:
        uf.fullname = input
        asyncCheck chatid << (enterGradeT, selectGrades)
        /-> sfGrade

      of sfGrade:
        let i = gradesSchoolT.find(input)
        if i == NotFound:
          asyncCheck chatid << invalidInputT
        else:
          uf.grade = i + 7

          if uf.grade in 7..9:
            gotoNumber()
          else:
            asyncCheck chatid << (enterMajorT, selectMajors)
            /-> sfMajor

      of sfMajor:
        if input notin majorsT:
          asyncCheck chatid << invalidInputT
        else:
          uf.major = some input
          goToNumber()

      of sfNumber:
        if isPhoneNumber input:
          uf.phoneNumber = input

          case FormKinds(uf.kind):
          of fkReportProblem:
            /-> sfContent
            asyncCheck chatid << enterProblemDescriptionT

          of fkRegisterInPlans:
            /-> sfConfirmBefore
            asyncCheck redirect(reFillform, args)

        else:
          asyncCheck chatid << phoneNumberValidationNoteT

      of sfContent:
        uf.content = some input
        /-> sfConfirmBefore
        asyncCheck redirect(reFillform, %*[chatid, ""])

      of sfConfirmBefore:
        let planTitle =
          if issome uf.planid:
            some ++db.getPlan(uf.planid.get).get.title
          else:
            none string

        discard await chatid << fullFormString(uf, planTitle)
        asyncCheck chatid << (sendIfYouSureOtherwiseCancelAndRefillT, formEndReply)
        /-> sfConfirm

      of sfConfirm:
        case input:

        of submitT:
          \+db.addForm(uf)
          forget uctx.form
          asyncCheck chatid << yourFormHasSubmittedT
          asyncCheck redirect(reEnterhome, args)

        else:
          asyncCheck chatid << invalidInputT

      else: impossible()

  route(chatid: int64) as "verify_user":
    try:
      let msg = u.message.get
      if issome msg.contact:
        let
          ct = msg.contact.get
          userInfo = await ct.phoneNumber.getUserInfo # number

        dbworks dbfpath:
          db.addMember(chatid, userinfo.display_name,
            (ct.firstname & " " & ct.lastname.get("")),
            ct.phoneNumber, userInfo.is_admin.int, unixNow())

          uctx.membership = db.getMember(chatid)

        asyncCheck chatid << (greeting(userinfo.displayName), noReply)
        asyncCheck redirect(reEnterhome, args)

      else:
        asyncCheck chatid << pleaseSendByYourCantactT

    except ValueError:
      asyncCheck chatid << wrongNumberT

  route(chatid: int64, input: string) as "admin_dashboard":
    case input:
    of "":
      asyncCheck chatid << (chooseOneT, adminDashboardReply)
      /-> sAdminDashboard

    of cancelT:
      asyncCheck redirect(reEnterhome, args)

    of addPostT:
      /-> sPost
      asyncCheck redirect(reUpsertpost, args)

    of addPlanT:
      /-> sAddPlan
      asyncCheck redirect(reAddplan, args)

    of removePlanT:
      /-> sDeletePlan
      asyncCheck redirect(reDeleteplan, args)

    of submittedFormsT:
      asyncCheck redirect(reSubmittedforms, args)

    of addQuizT:
      /-> sAddQuiz
      asyncCheck redirect(reAdd_quiz, %*[chatid, ""])

    of removeQuizT:
      /-> sDeleteQuiz
      asyncCheck redirect(reDelete_quiz, %*[chatid, ""])

    else:
      asyncCheck chatid << invalidInputT

  route(chatid: int64, input: string) as "add_plan":
    if input == cancelT:
      forget uctx.plan
      asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

    else:
      case uctx.stage:
      of sAddPlan:
        uctx.plan = some PlanModel()
        asyncCheck chatid << (selectPlanKindT, selectPlanKindsReply)
        /-> spKind

      of spKind:
        template done(planKind): untyped =
          /-> spTitle
          pl.kind = planKind.ord
          asyncCheck chatid << (sendPlanTitleT, cancelReply)

        case input:
        of $pkConsulting: done pkConsulting
        of $pkEducational: done pkEducational
        else: asyncCheck chatid << invalidInputT

      of spTitle:
        pl.title = input
        asyncCheck chatid << sendOrForwardVideoT
        /-> spVideo

      of spVideo:
        let fid = getVideoFileId(u.message)

        if isSome fid:
          pl.video_path = fid.get
          asyncCheck chatid << enterPlanDescT
          /-> spDesc

        else:
          asyncCheck chatid << whatYouveJustSentIsNotAvideoT

      of spDesc:
        pl.description = input
        asyncCheck chatid << enterPlanLinkT
        /-> spLink

      of spLink:
        pl.link = input
        \+db.addPlan pl
        forget uctx.plan
        asyncCheck chatid << planAddedT
        asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

      else: impossible()

  route(chatid: int64, input: string) as "delete_plan":
    template cancelJob: untyped =
      forget uctx.plan
      asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

    if input == cancelT:
      cancelJob()

    else:
      case uctx.stage:
      of sDeletePlan:
        uctx.plan = some PlanModel()
        asyncCheck chatid << (selectPlanKindT, selectPlanKindsReply)

      of sdpKind:
        template job(planKind): untyped =
          pl.kind = planKind.ord
          asyncCheck chatid << (selectPlanTitleT,
              newReplyKeyboardMarkupEveryRow ++db.getPlansTitles(planKind))

        case input:
        of $pkConsulting: job pkConsulting
        of $pkEducational: job pkEducational
        else: asyncCheck chatid << invalidInputT

      of sdqTitle:
        \+db.deletePlan(PlanKinds(pl.kind), input)
        asyncCheck chatid << planDeletedT
        cancelJob()

      else: impossible()

  route(chatid: int64, input: string) as "upsert_post":
    if input == cancelT:
      forget uctx.post
      asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

    else:
      case uctx.stage:
      of sPost:
        asyncCheck chatid << (enterPostTitleT, postKindsReply)
        uctx.post = some PostModel()
        /-> spoKind

      of spoKind:
        case input:
        of $pokIntroduction:
          ps.kind = pokIntroduction.ord
          asyncCheck chatid << sendOrForwardVideoT
          /-> spoVideo_path
        
        else:
          asyncCheck chatid << invalidInputT

      of spoVideo_path:
        let fid = getVideoFileId(u.message)

        if isSome fid:
          ps.video_path = fid.get
          asyncCheck chatid << enterPostDescT
          /-> spoDesc

        else:
          asyncCheck chatid << whatYouveJustSentIsNotAvideoT

      of spoDesc:
        ps.description = input
        \+db.upsertPost(ps)
        asyncCheck chatid << postSubmittedT
        forget uctx.post
        asyncCheck redirect(reEnterhome, args)

      else: impossible()

  route(chatid: int64) as "submitted_forms":
    let forms = ++db.getForms(int.high, pageSize, saLess, Descending)

    if forms.len == 0:
      asyncCheck chatid << noFormsAvailableT
      asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

    else:
      uctx.queryPaging = some initQueryPageInfo(sfForms)
      asyncCheck chatid << (yourRecordsT, cancelReply)

      qp.msgid = some (await chatid << (
        forms.mapIt(fullFormString(it.form, it.planName)).join "\n\n",
        genQueryPageInlineBtns(0)
      )).messageid

      qp.indexRange = forms[^1].form.id .. forms[0].form.id
      /-> sScroll

  route(chatid: int64, input: string) as "delete_quiz":
    if input == cancelT:
      asyncCheck redirect(reEnterhome, %*[chatid])

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
            discard ++db.deleteQuiz(uctx.quizidToDelete.get)
            chatid << quizGotDeletedT
          else:
            chatid << operationCancelledT

        uctx.quizidToDelete.forget
        asyncCheck redirect(reEnterhome, %*[chatid])

      else:
        discard

  route(chatid: int64, input: string) as "add_quiz":
    let msgid = u.message.get.messageId

    if input == cancelT:
      uctx.quizCreation.forget
      asyncCheck redirect(reAdmindashboard, %*[chatid, ""])

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
        qc.quiz.time = protectedParseint(input, minQuizTime)
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
        asyncCheck redirect(reAdd_question, %*[chatid, ""])

      else:
        impossible()

  route(chatid: int64, input: string) as "add_question":
    let
      msg = u.message.get
      msgid = msg.messageid

    template qs: untyped = uctx.quizCreation.get.questions
    template lqi: untyped = qc.msgids.questions[^1]

    if input == endT and uctx.stage == sAQQPic:
      dbworks dbfpath:
        let tg = db.getOrInsertTag(
          qc.tag.grade, qc.tag.lesson, qc.tag.chapter)
        db.addQuiz(
          qc.quiz.name,
          qc.quiz.description,
          qc.quiz.time,
          tg.id,
          unixNow(),
          qc.questions)

      asyncCheck chatid << quizAddedDialog(qc.quiz.name)
      asyncCheck redirect(reEnterhome, %*[chatid])
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
        asyncCheck redirect(reAdd_question, %*[chatid, ""])

      else: impossible()

  route(chatid: int64, msgid: int) as "edit_quiz_creation":
    template msg: untyped = u.editedmessage.get
    template input: untyped = msg.text.get("")
    template qi: untyped = qc.questions[index]

    let (ctx, index, field) = findEditedMessageIdContext(qc, msgid)
    case ctx:
    of qcmsQuiz, qcmsTag:
      case field:
      of qzfName: qc.quiz.name = input
      of qzfTime: qc.quiz.time = protectedParseint(input, minQuizTime)
      of qzfDescription: qc.quiz.description = input
      of tfGrade: qc.tag.grade = protectedParseint input
      of tfLesson: qc.tag.lesson = input
      of tfChapter: qc.tag.chapter = protectedParseint input
      else: impossible()

      asyncCheck chatid << changeQuizFieldAlert(field)

    of qcmsQuestions:
      case field:
      of qfPhotoPath:
        qi.photo_path =
          if issome msg.photo: getBiggestPhotoFileId msg
          else: ""

      of qfDescription: qi.description = input
      of qfWhy: qi.why = input
      of qfAnswer: qi.answer = protectedParseint(input, 1, 4)
      else: impossible()
      asyncCheck chatid << fmt"{fieldT} '{field}' {fromQuestionNumberT} {(index+1)} {changedT}"

    of qcmsNothing:
      asyncCheck chatid << nothingHasChangedT

  route(chatid: int64, input: string) as "quiz_menu":
    case input:
    of cancelT:
      asyncCheck redirect(reEnterhome, args)

    of "":
      asyncCheck chatid << (chooseOneT, quizMenuReply)
      /-> sQuizMenu

    of findQuizT:
      /-> sFindQuizMain
      uctx.quizQuery = some QuizQuery()
      asyncCheck chatid << (findQuizDialogT, quizFilterReply)

    of myRecordsT:
      /-> sMyRecords
      asyncCheck redirect(reMy_records, %*[chatid])

    else:
      asyncCheck chatid << invalidInputT

  route(chatid: int64, input: string) as "find_quiz":
    template goBack: untyped = 
      /-> sFindQuizMain

    case input:
    of findQuizChangeNameT:
      asyncCheck chatid << enterQuizNameToSearchT
      /-> sFQname

    of findQuizChangeGradeT:
      asyncCheck chatid << enterQuizGradeToSearchT
      /-> sFQgrade

    of findQuizChangeLessonT:
      asyncCheck chatid << enterQuizLessonToSearchT
      /-> sFQlesson

    of showFiltersT:
      asyncCheck chatid << $qq

    of showResultsT:
      asyncCheck chatid << $qq

      let quizzes = ++ db.findQuizzes(qq, int64.high, pageSize, saLess, Descending)

      if quizzes.len == 0:
        asyncCheck chatid << noResultFoundT

      else:
        asyncCheck chatid << (yourSearchResultT, cancelReply)
        uctx.queryPaging = some initQueryPageInfo(sfQuiz)

        qp.msgid = some (await chatid << (
          quizzes.map(miniQuizInfo).join "\n",
          genQueryPageInlineBtns(0)
        )).messageid

        qp.indexrange = quizzes[^1].quiz.id .. quizzes[0].quiz.id
        qp.context = sfQuiz
        /-> sScroll

    of cancelT:
      uctx.quizQuery.forget
      uctx.queryPaging.forget
      asyncCheck redirect(reQuizmenu, %*[chatid, ""])

    else:
      template alertChange(field: QuizCreateFields): untyped =
        asyncCheck chatid << changeQuizFieldAlert(field)

      case uctx.stage:
      of sfindQuizMain:
        asyncCheck chatid << findQuizDialogT

      of sFQname:
        qq.name = some input
        alertChange qzfName
        goBack()

      of sFQgrade:
        qq.grade = some protectedParseint input
        alertChange tfGrade
        goBack()

      of sFQlesson:
        qq.lesson = some input
        alertChange tfLesson
        goBack()

      else: impossible()

  route(chatid: int64) as "my_records":
    let recs = ++ db.getMyRecords(chatid, int64.high, pageSize, saLess, Descending)

    if recs.len == 0:
      asyncCheck chatid << noRecordsAvailableT
      /-> sQuizMenu

    else:
      uctx.queryPaging = some initQueryPageInfo(sfQuiz)
      asyncCheck chatid << (yourRecordsT, cancelReply)

      qp.msgid = some (await chatid << (
        recs.map(miniRecordInfo).join "\n\n",
        genQueryPageInlineBtns(0)
      )).messageid

      qp.indexrange = recs[^1].record.id .. recs[0].record.id
      qp.context = sfmyRecords
      /-> sScroll

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
            let quizzes = ++ db.findQuizzes(qq, qp.indexRange[dir], pageSize,
                dir, Descending)

            if quizzes.len == 0:
              result = itsTheEndT

            else:
              qp.indexRange = quizzes[^1].quiz.id .. quizzes[0].quiz.id
              qp.page.inc btnDir.toInt

              asyncCheck (chatid, msgid) <^ (
                quizzes.map(miniQuizInfo).join "\n",
                genQueryPageInlineBtns(qp.page))

          of sfmyRecords:
            let recs = ++ db.getMyRecords(chatid, qp.indexRange[dir],
                  pageSize, dir, Descending)

            if recs.len != 0:
              qp.indexRange = recs[^1].record.id .. recs[0].record.id
              qp.page.inc btnDir.toInt

              asyncCheck (chatid, msgid) <^ (
                recs.map(miniRecordInfo).join "\n\n",
                genQueryPageInlineBtns(qp.page))

            else:
              result = itsTheEndT

          of sfForms:
            let forms = ++ db.getForms(qp.indexRange[dir], pageSize, dir, Descending)

            if forms.len != 0:
              qp.indexRange = forms[^1].form.id .. forms[0].form.id
              qp.page.inc btnDir.toInt

              asyncCheck (chatid, msgid) <^ (
                forms.mapit(fullFormString(it[0], it[1])).join "\n\n",
                genQueryPageInlineBtns(qp.page))

            else:
              result = itsTheEndT

        else:
          result = itsTheStartT

      else: result = messageExpiredT
    else: result = wrongCommandT

  route(chatid: int64, input: string) as "middle_of_scroll":
    if input == cancelT:
      asyncCheck redirect(reEnterhome, %*[chatid])

  command(chatid: int64, param: string) as "show_quiz":
    let
      quizid = parseint param
      qm = ++ db.getQuizInfo(quizid)

    asyncCheck:
      if qm.issome:
        let
          rec = ++ db.getRecordFor(chatid, qm.get.quiz.id)

          text = fullQuizInfo(qm.get, rec)

        if rec.issome:
          chatid << text
        else:
          chatid << (text, genTakeQuizInlineBtn(quizid))

      else:
        chatid << quizNotFoundT

  command(chatid: int64, param: string) as "get_rank":
    let
      quizid = parseint param
      rank = ++ db.getRank(chatid, quizid)

    asyncCheck chatid << (
      if isSome rank: fmt"{yourRankInThisQuizYetT}: {rank.get}"
      else: youHaventAttendInThisQUizT)

  callbackQuery(chatid: int64, _: int, param: string) as "take_quiz":
    if not isDoingQuiz:
      let
        quizid = parseint param
        quiz = ++ db.getQuizItself(quizid)

      if issome quiz:
        if not ++ db.isRecordExistsFor(chatid, quizid):
          asyncCheck chatid << quizWillStartSoonT

          uctx.record = some QuizTaking()
          myrecord.quiz = quiz.get
          myrecord.questions = ++ db.getQuestions(quizid)

          myrecord.questionsOrder = toseq(0 .. myrecord.questions.high).dup(shuffle)
          let fqi = myrecord.questionsOrder[0] # first question index

          myrecord.answersheet = newSeqWith(myrecord.questions.len, 0)
          myrecord.starttime = now()
          myrecord.lastCheckedTime = now()
          myrecord.qi = 0

          myrecord.quizTimeMsgId = (await chatid <<
              timeformat myrecord.quiz.time).messageId

          asyncCheck bot.pinChatMessage($chatid, myrecord.quizTimeMsgId)

          myrecord.lastQuestionPhotoUrl = myrecord.questions[fqi].photo_path or defaultQuestionPhotoUrl
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

  callbackQuery(chatid: int64, msgid: int, param: string) as "jump_question":
    if isDoingQuiz and (msgid in myrecord.savedMsgIds):
      let
        newQuestionIndex = parseint param
        q = myrecord.questions[myrecord.questionsOrder[newQuestionIndex]]

      if myrecord.qi != newQuestionIndex:
        myrecord.qi = newQuestionIndex
        asyncCheck (chatid, myrecord.questionDescMsgId) <^ (
          questionSerialize(q, newQuestionIndex), answerKeyboard)

        # if you set the same photo, telegram complains
        let newPhotoUrl = q.photo_path or defaultQuestionPhotoUrl
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
        reJump_question, %*[chatid, msgid, $targetQuestionIndex])

  callbackQuery(chatid: int64, msgid: int, param: string) as "select_answer":
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
      quiz = ++ db.getQuizItself(quizid)

    if quiz.issome:
      let rec = ++ db.getRecordFor(chatid, quizid)
      if rec.issome:
        let
          questions = ++ db.getQuestions(quizid)
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

  event(chatId: int64) as "update_timer":
    if isDoingQuiz and myrecord.isReady:
      let
        quiz = myrecord.quiz
        newtime = quiz.time - (now() - myrecord.startTime).inseconds

      if newtime > 0:
        asyncCheck (chatid, myrecord.quizTimeMsgId) <^ timeformat(newtime)

  event(chatId: int64) as "end_quiz":
    if isDoingQuiz:

      # delete quiz messages
      let r = myrecord
      for msgId in r.savedMsgIds:
        asyncCheck chatId <! msgid

      let percent = getPercent(
        r.answerSheet, r.questionsOrder.mapIt(r.questions[it].answer.int))

      # save record
      \+db.addRecord(r.quiz.id, chatid, r.answerSheet.join,
        ($r.questionsOrder).substr(1), percent, unixNow())

      # show complete result
      asyncCheck chatid << recordResultDialog(r.quiz, percent)

      uctx.record.forget
      asyncCheck redirect(reEnterhome, %*[chatid])

  route(chatid: int64, input: string) as "middle_of_quiz":
    case input
    of endT:
      asyncCheck redirect(reEnd_quiz, %*[chatid, ""])

    of cancelT:
      uctx.record.forget
      asyncCheck chatid << quizCancelledT
      asyncCheck redirect(reEnterhome, %*[chatid])

    else:
      asyncCheck chatid << invalidInputT

  command(chatid: int64) as "invalid_command":
    asyncCheck chatid << wrongCommandT

  callbackQuery() as "dont_care": discard
