import std/[options, strutils, strformat, times, sequtils]
import telebot, jalali_nim
import controller, database/[queries, models], utils


func escapeMarkdownV2*(s: string): string =
    result = newStringOfCap(s.len * 2)
    for c in s:
        if c in "_*[]()~`>#+-=|{}.!\\":
            result.add '\\'

        result.add c

func bold*(s: string): string = fmt"*{s}*"
func italic*(s: string): string = fmt"_{s}_"
func underline*(s: string): string = fmt"__{s}__"
func spoiler*(s: string): string = fmt"||{s}||"
func link*(url, hover: string): string = fmt"[{url}]({hover})"

const
    cancelT* = "انصراف"
    invalidInputT* = "ورودی اشتباه"
    wrongCommandT* = "دستور اشتباه"
    returningT* = "بازگشت ..."
    menuT* = "منو"
    loginT* = "ورود"
    adminT* = "ادمین"
    withoutPhotoT* = "بدون عکس"
    enterPhoneNumberT* = "شماره خود را وارد کنید"
    wrongNumberT* = [
      "شماره اشتباه میباشد",
      "مطمئن شو که از همون شماره ای استفاده میکنی که توی سایت باهاش ثبت نام کردی"
    ].join("\n")

    helpT* = "راهنما"
    gradesT* = "پایه ها"
    chaptersT* = "شماره فصل ها"
    minQuizTimeT* = "حداقل زمان آزمون"
    secondT* = "ثانیه"
    positiveIntegerT* = "عدد صحیح بزرگتر از صفر"
    areT* = "هستند"
    isT* = "است"

    selectOptionsT* = "‌یکی از گزینه ها رو انتخاب کنید‌"
    sendAdminPassT* = "رمز را وارد کنید"
    passwordIsWrongT* = "رمز اشتباه است"
    loggedInAsAdminT* = "به عنوان ادمین وارد شدید"

    sendContactIntoT* = "ارسال اطلاعات حساب تلگرام"
    pleaseSendByYourCantactT* = "لطفا از طریق کیبرد ربات تلگرام، شماره خود را ارسال کنید"

    addQuizT* = "افزودن آزمون"
    removeQuizT* = "حذف آزمون"
    enterQuizNameT* = "نام آزمون را وارد کنید"
    enterQuizInfoT* = "توضیحات آزمون را وارد کنید"
    enterQuizTimeT* = escapeMarkdownV2 "زمان آزمون را به ثانیه وارد کنید (عدد صحیح)"
    enterQuizGradeT* = "پایه تحصیلی آزمون را وارد کنید"
    enterQuizLessonT* = "نام درس آزمون را انتخاب کنید"
    enterQuizChapterT* = "شماره فصل درس آزمون را وارد کنید"

    quizNotFoundT* = "آزمون مورد نظر پیدا نشد"
    noResultFoundT* = "نتیجه ایی یافت نشد"

    findQuizDialogT* = "میتوانید به طور اختیاری فیلتر هایی اعمال کنید و سپس روی دکمه جستجوی آزمون بزنید"
    findQuizT* = "جستجوی آزمون"
    findQuizChangeGradeT* = "پایه"
    findQuizChangeNameT* = "نام آزمون"
    findQuizChangeLessonT* = "نام درس"
    showFiltersT* = "نمایش فیلتر ها"

    chooseOneT* = "یکی را انتخاب کنید"

    enterQuestionInfoT* = "توضیحات سوال را وارد کنید"
    enterQuestionAnswerT* = "جواب سوال را وارد کنید"
    enterQuestionWhyY* = "درباره دلیل درستی جواب توضیح دهید"
    addFirstQuizQuestionT* = "به ترتیب اطلاعات وارد شده برای هر سوال را وارد کنید"
    addQuizQuestionMoreT* = "یابا دکمه 'خاتمه' آزمون را ثبت کنید یا اطلاعات سوال جدید را وارد کنید"
    uploadQuizQuestionPicT* = "تصویر سوال را در صورت وجود ارسال کنید در غیر این صورت روی دکمه 'بدون عکس' بزنید"

    quizWillStartSoonT* = "آزمون انتخابی تا لحظاتی دیگر شروع میشود"

    askPasswordAdmin* = "رمز ادمین را وارد کنید"
    youWereAttendedBeforeT* = "قبلا در این آزمون شرکت بودید"
    yourLastResultIsT* = "نتیجه قبلی شما"
    analyzeYourAnswersT* = "آزمونت رو تحلیل کن"
    takeQuizT* = "شرکت در آزمون"

    questionT* = "سوال"
    quizNameT* = "نام آزمون"
    numberOfQuestionsT* = "تعداد سوالات"
    detailsT* = "جزئیات"
    dearT* = "عزیز"
    welcomeT* = "خوش آمدید"

    emptyBoxJ* = "◻"
    correctBoxJ* = "✅"
    dangerJ* = "⚠️"

    gotoQuestionT* = "برو به سوال"
    emptyT* = "خالی"
    nextT* = "بعدی"
    previousT* = "قبلی"
    quizCancelledT* = "آزمون لغو شد"
    operationCancelledT* = "عملیات لغو شد"

    youInTheQuizT* = "شما در آزمون"
    gradeT* = "پایه"
    youGotT* = "را کسب کردید"
    lessonT* = "درس"
    scoreT* = "نمره"
    chapterT* = "فصل"

    durationT* = "مدت"
    endT* = "خاتمه"

    pointRightJ* = "👉"
    pointLeftJ* = "👈"
    wrongJ* = "❌"
    youHaventAttendInThisQUizT* = "شما در این آزمون شرکت نکرده اید"

    reasonT* = "دلیل"
    questionDescT* = "متن سوال"
    yourAnswerT* = "جواب شما"
    correctAnswerT* = "جواب درست"
    comparisionT* = "مقایسه"
    quizOfNumberT* = "سوال شماره"

    quizT* = "آزمون"
    gotSavedُSuccessfullyT* = "با موفقیت ذخیره شد"
    areYouSureT* = "آیا مطمئن هستید؟"
    idT* = "شناسه"

    enterQuizIdT* = "شناسه آزمون را وارد کنید"
    yesT* = "بله"
    noTx* = "خیر"
    resultT* = "نتیجه"
    commandsT* = "دستورات"
    numberT* = "عدد"
    resetT* = "بازگشت به حالت اول"
    startT* = "راه انداختن ربات"

    quizGotDeletedT* = "آزمون مورد نظر حذف شد"
    quizStartedT* = "آزمون شروع شد"
    showResultsT* = "نمایش نتیجه"
    yourSearchResultT* = "نتیجه جستجوی شما"

    pointLeftTJ* = fmt"{previousT} {pointLeftJ}"
    pointRightTJ* = fmt"{pointRightJ} {nextT}"
    messageExpiredT* = "پیام منقضی شده است"

    myRecordsT* = "سابقه آزمون ها"
    yourRecordsT* = "سابقه آزمون های شما"
    itsTheEndT* = "آخرشه"
    itsTheStartT* = "اولشه"

    nothingHasChangedT* = "چیزی تغییر نکرده"

    fieldT* = "مشخصه"
    changedT* = "تغییر کرد"
    fromQuestionNumberT* = "از سوال شماره"

    noRecordsAvailableT* = "سابقه ای وجود ندارد"
    createdAtT* = "تاریخ ایجاد"
    persianNumbers = ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]
    dateT* = "تاریخ"
    hourT* = "ساعت"

    calcRank* = "محاسبه رتبه"
    nameT* = "نام"
    yourRankInThisQuizYetT* = "رتبه شما در این آزمون فعلا"
    appliedFiltersT* = "فیلتر های اعمالی"
    minesT* = "-"
    separatorLineEscaped* = escapeMarkdownV2:
        "-----------------------"

    sendIfYouSureOtherwiseCancelAndRefillT * = [
      "اگر اطلاعات فرم درست وارد شده، روی دکمه ثبت بزنید",
      "در غیر این صورت گزینه انصراف را بزنید و فرم رو از اول پرکنید"
    ].join "\n\n"

    submitT* = "ثبت"

    youAreTakingQuizT* = "شما در حال انجام آزمون هستید"
    youHaveTakenTheQuizBeforeT* = "شما قبلا در این آزمون شرکت کرده اید"

    firstTimeStartMsgT* = escapeMarkdownV2:
        "سلام! به ربات سایت رخشان خوش اومدی"

    postNotFoundT* = "مطلب پیدا نشد"
    phoneNumberValidationNoteT* =
        "شماره تلفن باید فقط با اعداد انگلیسی نوشته شده باشه"

    knowUsT* = "آشنایی با ما"
    knowConsultingPlansT* = "آشنایی با طرح های مشاوره"
    knowEducationalPlansT* = "آشنایی با طرح های آموزشی درسی"
    registerInVaiousPlansT* = "ثبت نام در طرح های مختلف"
    reportProblemsT* = "ثبت مشکلات"
    adminPanelT* = "پنل ادمین"

    # form
    submittedFormsT* = "فرم های ارسالی"
    enterProblemDescriptionT* = "توضیحات مشکل را بنویسید"
    enterGradeT* = "پایه تحصیلی خود را وارد کنید"
    enterMajorT* = "رشته تحصیلی خود را وارد کنید"
    enterFullNameT* = "نام و نام خانوادگی خود را وارد کنید"
    thisIsTheFormYouJustFilledT* = "این فرمی است که همین الان پرکردید"
    yourFormHasSubmittedT* = "فرم شما ارسال شد"
    noFormsAvailableT* = "فرم پرکرده ای وجود ندارد"

    sendOrForwardVideoT* = "ویدئوی مربوطه را ارسال یا فوروارد کنید"

    # plan
    addPlanT* = "افزودن طرح"
    planAddedT* = "طرح ثبت شد"
    removePlanT* = "حذف طرح"
    planDeletedT* = "طرح حذف شد"
    selectPlanKindT* = "نوع طرح را اتنخاب کنید"
    selectPlanTitleT* = "عنوان طرح را اتنخاب کنید"
    sendPlanTitleT* = "عنوان طرح را انتخاب کنید"
    enterPlanDescT* = "توضیحات طرح را بنویسید"
    enterPlanLinkT* = "لینک طرح را وارد کنید"
    registerationLinkT* = "لیتک ثبت نام"

    # post
    addPostT* = "افزودن مطلب"
    enterPostTitleT* = "عنوان مطلب را بنویسید"
    enterPostDescT* = "توضیحات مطلب را بنویسید"
    postSubmittedT* = "مطلب ثبت شد"

    # rrror
    whatYouveJustSentIsNotAvideoT* = "پیام ارسال شده، ویدئو نیست"

    loggedInAsT* = "وارد شده به عنوان"
    inputIsnotAIntegerT* = "ورودی عدد نیست"
    numberIsnotInValidRangeT* = "عدد داده شده در محدوده مجاز نیست"
    databaseErrorT* = "مشکل با دیتابیس"
    runtimeErrorT* = "مشکل در داخلی"
    someErrorT* = "مشکلی پیش آمده"
    rangeErrorT* = "ورودی داده شده در بازه مجاز نیست"
    youMustLoginToUseThisSection* = "برای استفاده از این بخش، باید وارد شوید"

    enterQuizNameToSearchT* = "نام آزمون مورد نظر را وارد کمید"
    enterQuizGradeToSearchT* = "پایه آزمون را برای جستجو وارد کنید"
    enterQuizLessonToSearchT* = "نام درس آزمون را برای جستحو وارد کنید"

    gradesSchoolT*: array[7..12, string] = [
      "هفتم",
      "هشتم",
      "نهم",
      "دهم",
      "یازدهم",
      "دوازدهم",
    ]

    majorsT* = [
      "ریاضی فیزیک",
      "تجربی",
      "انسانی",
    ]

func genQueryPageInlineBtns*(pageIndex: int): InlineKeyboardMarkup =
    newInlineKeyboardMarkup @[
      toInlineButtons @[
        (pointLeftTJ, "/m-"),
        ($(pageIndex + 1), "/d"), # no op
        (pointRightTJ, "/m+"),
    ]]

func genTakeQuizInlineBtn*(quizId: int64): InlineKeyboardMarkup =
    result = InlineKeyboardMarkup(kind: kInlineKeyboardMarkup)
    result.inlineKeyboard = @[@[
      InlineKeyboardButton(
        text: takeQuizT,
        callbackData: some fmt"/t{quizid}"
    )]]

func genQuestionJumpBtns*(number: int): InlineKeyboardMarkup =
    var btnRows = newSeqOfCap[seq[InlineKeyboardButton]](number div 4)

    for offset in countup(1, number, 4):
        var acc = newSeqOfCap[InlineKeyboardButton](4)
        for n in offset .. min(offset + 3, number):
            acc.add InlineKeyboardButton(
              text: $n,
              callbackData: some fmt"/j{(n-1)}")

        btnRows.add acc

    result = newInlineKeyboardMarkup()
    result.inlineKeyboard = btnRows

func toPersianNumbers*(str: string): string =
    for c in str:
        if c in '0' .. '9':
            result &= persianNumbers[c.parseint]
        else:
            result.add c

func greeting*(uname: string): string =
    fmt"'{escapeMarkdownV2 uname}' {dearT} {welcomeT}"

func timeFormat*[T: SomeInteger](t: T): string =
    let d = initDuration(seconds = t).toParts
    fmt"{d[Hours]:02}:{d[Minutes]:02}:{d[Seconds]:02}"

proc unixDatetimeFormat*(ud: int64): string =
    let
        dt = ud.fromUnix.local
        j = gregorian_to_jalali(dt.year, dt.month.int, dt.monthday.int)
    escapeMarkdownV2 toPersianNumbers fmt"""{j[0]}/{j[1]:02}/{j[2]:02} | {dt.format("HH:mm:ss")}"""

func percentSerialize*(n: SomeFloat): string =
    escapeMarkdownV2 fmt"{n:.2f}%"

proc miniRecordInfo*(ri: RecordInfo): string =
    [
      fmt"{bold quizNameT}: {escapeMarkdownV2 ri.quiz.name}",
      fmt"{bold resultT}: {percentSerialize ri.record.percent}",
      fmt"{bold dateT}: {unixDatetimeFormat ri.record.created_at}",
      fmt"{bold calcRank}: /r{ri.quiz.id}",
      fmt"{bold analyzeYourAnswersT}: /a{ri.quiz.id}"
    ].join "\n"

proc miniQuizInfo*(qi: QuizInfo): string =
    [
      fmt"{bold quizNameT}: {escapeMarkdownV2 qi.quiz.name}",
      fmt"{bold numberOfQuestionsT}: {qi.quiz.questions_count}",
      fmt"{bold gradeT}: {qi.tag.grade}",
      fmt"{bold lessonT}: {escapeMarkdownV2 qi.tag.lesson}",
      fmt"{bold createdAtT}: {unixDatetimeFormat qi.quiz.created_at}",
      fmt"{bold detailsT}: /q{qi.quiz.id}",
      "\n",
    ].join "\n"

proc fullQuizInfo*(qi: QuizInfo, rec: Option[RecordModel]): string =
    let recSection =
        if issome rec:
            [
              youWereAttendedBeforeT,
              fmt"{bold yourLastResultIsT}: {percentSerialize rec.get.percent}",
              fmt"{bold calcRank}: /r{qi.quiz.id}",
              fmt"{bold analyzeYourAnswersT}: /a{qi.quiz.id}",
            ].join "\n"

        else:
            "\n"

    [
      fmt"{bold $idT} {bold quizT}: {escapeMarkdownV2($qi.quiz.id)}",
      fmt"{bold quizNameT}: {escapeMarkdownV2 qi.quiz.name}",
      fmt"{bold gradeT}: {qi.tag.grade}",
      fmt"{bold lessonT}: {escapeMarkdownV2 qi.tag.lesson}",
      fmt"{bold chapterT}: {qi.tag.chapter}",
      fmt"{bold numberOfQuestionsT}: {qi.quiz.questions_count}",
      fmt"{bold durationT}: {timeFormat qi.quiz.time}",
      fmt"{bold createdAtT}: {unixDatetimeFormat qi.quiz.created_at}",
      recSection,
    ].join "\n"

func questionSerialize*(q: QuestionModel, index: int): string =
    fmt"""
    {questionT} {index+1}:
    
    {escapeMarkdownV2 q.description}
  """

func answerSerialize(ans: int): string =
    for i in 1..4:
        result.add:
            if ans == i: correctBoxJ
            else: emptyBoxJ

func answerSheetSerialize*(sheet: seq[int]): string =
    for i, n in sheet.pairs:
        result.add fmt"{(i+1):<3}\) {answerSerialize(n)}{'\n'}"

func recordResultDialog*(quiz: QuizModel, percent: float): string =
    let score = spoiler(percentSerialize percent)
    [
      fmt"{youInTheQuizT} '{escapeMarkdownV2 quiz.name}' {scoreT} {score} {youGotT}",
      fmt"{analyzeYourAnswersT}: /a{quiz.id}",
      fmt"{bold calcRank}: /r{quiz.id}",
    ].join("\n\n")

func questionAnswer(n: int): string =
    if n == 0: emptyT
    else: $n

func compareEmoji(test, correct: int): string =
    if test == 0: dangerJ
    elif test == correct: correctBoxJ
    else: wrongJ

func questionAnalyzeDialog*(
  index: int, q: QuestionModel, yourAnswer: int
): string =
    [
      &"{bold quizOfNumberT}: {(index+1)}\n",
      &"{bold yourAnswerT}: {questionAnswer yourAnswer}",
      &"{bold correctAnswerT}: {q.answer}",
      &"{bold comparisionT}: {compareEmoji(yourAnswer, q.answer.int)}\n",
      &"{bold questionDescT}:\n{escapeMarkdownV2 q.description}\n",
      &"{bold reasonT}:\n{escapeMarkdownV2 q.why}",
    ].join "\n"

func quizAddedDialog*(qname: string): string =
    fmt"{quizT} '{qname}' {gotSavedُSuccessfullyT}"

func `$`*(f: QuizCreateFields): string =
    case f:
    of qzfName: "نام آزمون"
    of qzfTime: "زمان آزمون"
    of qzfDescription: "توضیحات آزمون"
    of tfGrade: "پایه آزمون"
    of tfLesson: "درس آزمون"
    of tfChapter: "فصل آزمون"
    of qfPhotoPath: "عکس سوال"
    of qfDescription: "متن سوال"
    of qfWhy: "دلیل درستی سوال"
    of qfAnswer: "جواب سوال"
    of qzNoField: "قیلد اشتباه"

func changeQuizFieldAlert*(f: QuizCreateFields): string =
    fmt"{fieldT} '{f}' {changedT}"

func getStr[T](o: Option[T], alternative: string): string =
    if issome o: $o.get
    else: alternative

func `$`*(qq: QuizQuery): string =
    [
      bold appliedFiltersT,
      separatorLineEscaped,
      fmt"{bold nameT}: {escapeMarkdownV2 qq.name.get(minesT)}",
      fmt"{bold gradeT}: {escapeMarkdownV2 qq.grade.getStr(minesT)}",
      fmt"{bold lessonT}: {escapeMarkdownV2 qq.lesson.getStr(minesT)}",
    ].join "\n"

func `$`*(pk: PlanKinds): string =
    case pk:
    of pkConsulting: "مشاوره ای"
    of pkEducational: "آموزشی درسی"

func `$`*(fk: FormKinds): string =
    case fk:
    of fkRegisterInPlans: "ثبت نام"
    of fkReportProblem: "گزارش مشکل"

func formFieldsToString(s: seq[array[2, string]]): string =
    s.mapIt(bold(it[0]) & ": " & it[1]).join "\n"

proc fullFormString*(f: FormModel, planTitle: Option[string]): string =
    let
        header = @[
          ["شماره فرم", $f.id],
          ["نوع فرم", $(FormKinds f.kind)]
        ]
        userInfo = @[
          ["نام", escapeMarkdownV2 $f.full_name],
          ["شماره تماس", $f.phone_number],
          ["پایه", $f.grade],
          ["رشته", f.major.get("")],
          ["تاریخ", unixDatetimeFormat(f.createdAt)],
        ]

    formFieldsToString:
        case FormKinds f.kind:
        of fkRegisterInPlans:
            header & @[["عنوان طرح", escapeMarkdownV2 planTitle.get]] & userInfo

        of fkReportProblem:
            header & userInfo & @[["متن", escapeMarkdownV2 f.content.get]]

func `$`*(p: PlanModel): string =
    [
      fmt"{bold p.title}",
      p.description,
      fmt"{bold registerationLinkT}: {p.link}",
    ].join "\n\n"

func `$`*(pok: PostKinds): string =
    case pok:
    of pokIntroduction: "معرفی"

func `$`*(p: PostModel): string =
    p.description

# keyboards -------------------------------

let
    noReply* = newReplyKeyboardRemove(true)

    commonFirstPageKeyboard = @[
      @[knowUsT],
      @[knowConsultingPlansT, knowEducationalPlansT],
      @[registerInVaiousPlansT, reportProblemsT],
      @[quizT],
    ]

    notLoggedInReply* = newReplyKeyboardMarkup:
        commonFirstPageKeyboard & @[ @[loginT]]

    memberReply* = newReplyKeyboardMarkup:
        commonFirstPageKeyboard

    adminReply* = newReplyKeyboardMarkup:
        commonFirstPageKeyboard & @[ @[adminPanelT]]

    adminDashboardReply* = newReplyKeyboardMarkup @[
      @[addPlanT, removePlanT],
      @[addQuizT, removeQuizT],
      @[submittedFormsT, addPostT],
      @[cancelT]
    ]

    postKindsReply* = newReplyKeyboardMarkupEveryRow @[
      $pokIntroduction,
      cancelT
    ]

    cancelReply* = newReplyKeyboardMarkup @[
      @[cancelT]
    ]

    yesOrNoReply* = newReplyKeyboardMarkup @[
      @[yesT],
      @[noTx],
    ]

    answersReply* = newReplyKeyboardMarkup @[
      @["1", "2", "3", "4"]
    ]

    doingQuizReply* = newReplyKeyboardMarkup @[
      @[endT],
      @[cancelT]
    ]

    addingMoreQuestionsReply* = newReplyKeyboardMarkup @[
      @[endT],
      @[withoutPhotoT]
    ]

    formEndReply* = newReplyKeyboardMarkupEveryRow @[
      submitT, cancelT
    ]

    selectPlanKindsReply* = newReplyKeyboardMarkupEveryRow @[
        $pkConsulting,
        $pkEducational,
        cancelT,
        ]

    withoutPhotoReply* = newReplyKeyboardMarkup @[
      @[withoutPhotoT]
    ]

    quizMenuReply* = newReplyKeyboardMarkupEveryRow @[
      findQuizT, myRecordsT, cancelT
    ]

    quizFilterReply* = newReplyKeyboardMarkup @[
      @[findQuizChangeGradeT, findQuizChangeLessonT, findQuizChangeNameT],
      @[showFiltersT],
      @[showResultsT, cancelT]
    ]

    addQuestionMoreThanOne* = newReplyKeyboardMarkup @[
      @[endT, cancelT],
    ]

    sendContactReply* = newReplyKeyboardMarkup @[@[
      KeyboardButton(text: sendContactIntoT, requestContact: some true)
    ]]

    answerBtns* = [
      ("1", "/p1"),
      ("2", "/p2"),
      ("3", "/p3"),
      ("4", "/p4"),
      (emptyT, "/p0"),
    ].toInlineButtons

    moveBtns* = @[
      (pointLeftTJ, "/g-"),
      (pointRightTJ, "/g+"),
    ].toInlineButtons

    answerKeyboard* = newInlineKeyboardMarkup(answerBtns, moveBtns)

    selectGrades* = newReplyKeyboardMarkup @[
      gradesSchoolT[7..9],
      gradesSchoolT[10..12],
      @[cancelT]
    ]

    selectMajors* = newReplyKeyboardMarkupEveryRow:
        majorsT.toseq & @[cancelT]
