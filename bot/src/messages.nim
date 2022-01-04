import options, strutils, strformat, times
import telebot
import ./telegram/[helper, controller], ./database/[queries, models], utils


func escapeMarkdownV2*(s: string): string =
    result = newStringOfCap(s.len * 2)
    for c in s:
        if c in "_*[]()~`>#+-=|{}.!":
            result.add '\\'

        result.add c

# texts: texts that are recieved from the client
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

    selectOptionsT* = "‌یکی از گزینه ها رو انتخاب کنید‌"
    sendAdminPassT* = "رمز را وارد کنید"
    passwordIsWrongT* = "رمز اشتباه است"
    loggedInAsAdminT* = "به عنوان ادمین وارد شدید"

    removeQuizT* = "حذف آزمون"
    sendContactIntoT* = "ارسال اطلاعات حساب تلگرام"
    pleaseSendByYourCantactT* = "لطفا از طریق کیبرد ربات تلگرام، شماره خود را ارسال کنید"

    addQuizT* = "اضافه کردن آزمون"
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
    findQuizChangeNameT* = "نام آزمون"
    findQuizChangeGradeT* = "پایه"
    findQuizChangeLessonT* = "نام درس"
    findQuizClearFiltersT* = "حذف فیلتر ها"

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

    yourRankInThisQuizT* = "رتبه شما در این آزمون"
    appliedFiltersT* = "فیلتر های اعمالی"
    separatorLine* = escapeMarkdownV2 "-----------------------"
    minesT* = escapeMarkdownV2 "-"
    nameT* = "نام"

    youAreTakingQuizT* = "شما در حال انجام آزمون هستید"
    youHaveTakenTheQuizBeforeT* = "شما قبلا در این آزمون شرکت کرده اید"

    firstTimeStartMsgT* = escapeMarkdownV2 [
      "سلام! به ربات سایت رخشان خوش اومدی",
      "برای استفاده از ربات اول باید شماره ات رو وارد کنی تا بشناسیمت"
    ].join "\n\n"

    loggedInAsT* = "وارد شده به عنوان"

let
    noReply* = newReplyKeyboardRemove(true)

    notLoggedInReply* = newReplyKeyboardMarkup @[
      @[loginT],
    ]

    cancelReply* = newReplyKeyboardMarkup @[
      @[cancelT]
    ]

    yesOrNoReply* = newReplyKeyboardMarkup @[
      @[yesT],
      @[noTx],
    ]

    endReply* = newReplyKeyboardMarkup @[
      @[endT]
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

    withoutPhotoReply* = newReplyKeyboardMarkup @[
      @[withoutPhotoT]
    ]

    memberReplyRaw = @[
      @[findQuizT, myRecordsT]
    ]

    quizFilterReply* = newReplyKeyboardMarkup @[
      @[findQuizChangeGradeT, findQuizChangeLessonT],
      @[findQuizChangeNameT],
      @[showResultsT, cancelT]
    ]

    adminReplyRaw = @[ @[addQuizT, removeQuizT]]

    addQuestionMoreThanOne* = newReplyKeyboardMarkup @[
      @[endT, cancelT],
    ]


    memberMenuReply* = newReplyKeyboardMarkup memberReplyRaw
    adminMenuReply* = newReplyKeyboardMarkup adminReplyRaw & memberReplyRaw

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

func genQueryPageInlineBtns*(pageIndex: int): InlineKeyboardMarkup =
    newInlineKeyboardMarkup @[
      toInlineButtons @[
        (pointLeftTJ, "/m-"),
        ($(pageIndex + 1), "/d"), # no op
        (pointRightTJ, "/m+"),
    ]]

func genTakeQuizInlineBtn*(quizId: int64): InlineKeyboardMarkup =
    result = InlineKeyboardMarkup(`type`: kInlineKeyboardMarkup)
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

func bold*(s: string): string = fmt"*{s}*"
func italic*(s: string): string = fmt"_{s}_"
func underline*(s: string): string = fmt"__{s}__"
func spoiler*(s: string): string = fmt"||{s}||"
func link*(url, hover: string): string = fmt"[{url}]({hover})"

func toPersianNumbers*(str: string): string =
    for c in str:
        if c in '0' .. '9':
            result &= persianNumbers[c.parseint]
        else:
            result.add c

func greeting*(uname: string): string =
    fmt"'{uname.escapeMarkdownV2}' {dearT} {welcomeT}"

func timeFormat*[T: SomeInteger](t: T): string =
    let d = initDuration(seconds = t).toParts
    fmt"{d[Hours]:02}:{d[Minutes]:02}:{d[Seconds]:02}"

proc unixDatetimeFormat*(dt: int64): string =
    let s = dt.fromUnix.format "yyyy/MM/dd '|' HH:mm:ss"
    escapeMarkdownV2 s.toPersianNumbers

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
      fmt"{bold $idT} {bold quizT}: {escapeMarkdownV2 $qi.quiz.id}",
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
    
    {q.description.escapeMarkdownV2}
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
      fmt"{youInTheQuizT} '{quiz.name.escapeMarkdownV2}' {scoreT} {score} {youGotT}",
      fmt"{analyzeYourAnswersT}: /a{quiz.id}",
      fmt"{bold calcRank}: /r{quiz.id}",
    ].join("\n\n")

func questionAnswer(n: int): string =
    if n == 0: emptyT
    else: $n

func toEmoji(cond: bool): string =
    if cond: correctBoxJ
    else: wrongJ

func questionAnalyzeDialog*(index: int, q: QuestionModel,
        yourAnswer: int): string =
    [
      &"{bold quizOfNumberT}: {(index+1)}\n",
      &"{bold yourAnswerT}: {questionAnswer yourAnswer}",
      &"{bold correctAnswerT}: {q.answer}",
      &"{bold comparisionT}: {toEmoji(q.answer == yourAnswer)}\n",
      &"{bold questionDescT}:\n{q.description.escapeMarkdownV2}\n",
      &"{bold reasonT}:\n{q.why.escapeMarkdownV2}",
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

func getStr[T](o: Option[T], alternative: string): string =
    if issome o: $o.get
    else: alternative

func `$`*(qq: QuizQuery): string =
    [
      bold appliedFiltersT,
      separatorLine,
      fmt"{bold nameT}: {qq.name.get(minesT)}",
      fmt"{bold gradeT}: {qq.grade.getStr(minesT)}",
      fmt"{bold lessonT}: {qq.lesson.getStr(minesT)}",
    ].join "\n"
