import options, strutils, strformat,times, strformat, sequtils
import telebot
import ./helper, ../database/queries, ../database/models

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
    enterQuizTimeT* = "زمان آزمون را وارد کنید"
    enterQuizGradeT* = "پایه تحصیلی آزمون را وارد کنید"
    enterQuizLessonT* = "نام درس آزمون را انتخاب کنید"
    enterQuizChapterT* = "شماره فصل درس آزمون را وارد کنید"

    invalidCommandT* = "دستور اشتباه"
    quizNotFoundT* = "آزمون مورد نظر پیدا نشد"

    findQuizDialogT* = "میتوانید به طور اختیاری فیلتر هایی اعمال کنید و سپس روی دکمه جستجوی آزمون بزنید"
    findQuizT* = "جستجوی آزمون"
    findQuizChangeNameT* = "نام آزمون"
    findQuizChangeGradeT* = "پایه"
    findQuizChangeLessonT* = "نام درس"
    findQuizClearFiltersT* = "حذف فیلتر ها"

    chooseOneT* = "یکی را انتخاب کنید"

    enterQuestionInfoT* = "توضیحات سوال را وارد کنید"
    enterQuestionAnswerT* = "جواب سوال را وارد کنید"
    addQuizQuestionFirstT* = "به ترتیب اطلاعات وارد شده برای هر سوال را وارد کنید"
    addQuizQuestionMoreT* = "با وارد کردن 'انصراف' وارد کردن سوالات را تمام کنید در غیر این صورت اطلاعات سوال بعدی ر وارد کنید"
    uploadQuizQuestionPicT* = "تصویر سوال را در صورت وجود ارسال کنید در غیر این صورت یک پیام حاوی متن ارسال کنید"

    quizWillStartSoonT* = "آزمون انتخابی تا لحظاتی دیگر شروع میشود"

    askPasswordAdmin* = "رمز ادمین را وارد کنید"
    youWereAttendedBeforeT* = "کردهشما قبلا در این آزمون شرکت بودید"
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

let
    notLoggedInReply* = newReplyKeyboardMarkup @[
        @[adminT],
        @[loginT],
    ]

    cancelReply* = newReplyKeyboardMarkup @[
      @[cancelT]
    ]

    memberReplyRaw = @[
      @[findQuizT]
    ]

    adminReplyRaw = @[ @[addQuizT, removeQuizT]]

    memberMenuReply* = newReplyKeyboardMarkup memberReplyRaw
    adminMenuReply* = newReplyKeyboardMarkup adminReplyRaw & memberReplyRaw

    sendContactReply* = newReplyKeyboardMarkup @[@[
      KeyboardButton(text: sendContactIntoT, requestContact: some true)
    ]]

    quizFilterReply* = newReplyKeyboardMarkup @[
      @[findQuizChangeGradeT, findQuizChangeLessonT],
      @[findQuizChangeNameT],
      @[findQuizT, cancelT]
    ]

    noReply* = newReplyKeyboardRemove(true)

let
    answerBtns* = [
      ("1",     "/p1"),
      ("2",     "/p2"),
      ("3",     "/p3"),
      ("4",     "/p4"),
      ("empty", "/p0"),
    ].toInlineButtons

    moveBtns* = @[
      ("prev", "/g-"),
      ("next", "/g+"),
    ].toInlineButtons

    answerKeyboard* = newInlineKeyboardMarkup(answerBtns, moveBtns)

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
      acc.add InlineKeyboardButton(text: $n, callbackData: some fmt"/j{(n-1)}")

    btnRows.add acc

  result = newInlineKeyboardMarkup()
  result.inlineKeyboard = btnRows

func escapeMarkdownV2*(s: sink string): string =
    for c in s:
        if c in "_*[]()~`>#+-=|{}.!":
            result.add '\\'

        result.add c

func bold*(s: string): string = fmt"*{s}*"
func italic*(s: string): string = fmt"_{s}_"
func underline*(s: string): string = fmt"__{s}__"
func spoiler*(s: string): string = fmt"||{s}||"
func link*(url, hover: string): string = fmt"[{url}]({hover})"

func greeting*(uname: string): string =
  fmt"{dearT} {uname.escapeMarkdownV2} {welcomeT}"

func miniQuizInfo*(qi: QuizInfoModel): string =
    [
      fmt"{quizNameT}: {qi.quiz.name}",
      fmt"{numberOfQuestionsT}: {qi.questions_number}",
      fmt"{detailsT}: /q{qi.quiz.id}",
      "\n",
    ].join "\n"

func fullQuizInfo*(qi: QuizInfoModel, rec: Option[RecordModel]): string =
    let recSection =
        if issome rec:
            [
              youWereAttendedBeforeT,
              [yourLastResultIsT, ": ", $rec.get.percent].join,
              [analyzeYourAnswersT, ": ", fmt"/a{rec.get.id}"].join,
            ].join "\n"

        else:
            "\n"

    [
      fmt"{quizNameT}: {qi.quiz.name}",
      fmt"{numberOfQuestionsT}: {qi.questions_number}",
       recSection,
    ].join "\n"

func timeFormat*[T: SomeInteger](t: T): string =
  let d = initDuration(seconds=t).toParts
  fmt"{d[Hours]:02}:{d[Minutes]:02}:{d[Seconds]:02}"

func questionSerialize*(q: QuestionModel, index:int): string =
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
    result.add fmt"{(i+1):<3} {answerSerialize(n)}{'\n'}"
