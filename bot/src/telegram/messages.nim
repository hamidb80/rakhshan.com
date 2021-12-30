import options
import telebot
import ./helper

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

    selectOptionsT* = "‌یکی از گزینه ها رو انتخاب کنید‌"
    sendAdminPassT* = "رمز را وارد کنید"
    passwordIsWrongT* = "رمز اشتباه است"
    loggedInAsAdminT* = "به عنوان ادمین وارد شدید"

    removeQuizT* = "حذف آزمون"
    sendContactIntoT* = "ارسال اطلاعات حساب تلگرام"

    addQuizT* = "اضافه کردن آزمون"
    enterQuizNameT* = "نام آزمون را وارد کنید"
    enterQuizInfoT* = "توضیحات آزمون را وارد کنید"
    enterQuizTimeT* = "زمان آزمون را وارد کنید"
    enterQuizGradeT* = "پایه تحصیلی آزمون را وارد کنید"
    enterQuizLessonT* = "نام درس آزمون را انتخاب کنید"
    enterQuizChapterT* = "شماره فصل درس آزمون را وارد کنید"

    findQuizDialogT* = "میتوانید به طور اختیاری فیلتر هایی اعمال کنید و سپس روی دکمه جستجوی آزمون بزنید"
    findQuizT* = "جستجوی آزمون"
    findQuizChangeNameT* = "نام آزمون"
    findQuizChangeGradeT* = "پایه"
    findQuizChangeLessonT* = "نام درس"
    findQuizClearFiltersT* = "حذف فیلتر ها"

    enterQuestionInfoT* = "توضیحات سوال را وارد کنید"
    enterQuestionAnswerT* = "جواب سوال را وارد کنید"
    addQuizQuestionFirstT* = "به ترتیب اطلاعات وارد شده برای هر سوال را وارد کنید"
    addQuizQuestionMoreT* = "با وارد کردن 'انصراف' وارد کردن سوالات را تمام کنید در غیر این صورت اطلاعات سوال بعدی ر وارد کنید"
    uploadQuizQuestionPicT* = "تصویر سوال را در صورت وجود ارسال کنید در غیر این صورت یک پیام حاوی متن ارسال کنید"

    quizWillStartSoonT* = "آزمون انتخابی تا لحظاتی دیگر شروع میشود"

    askPasswordAdmin* = "رمز ادمین را وارد کنید"


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

    memberReply* = newReplyKeyboardMarkup memberReplyRaw
    adminReply* = newReplyKeyboardMarkup adminReplyRaw & memberReplyRaw

    sendContactReply* = newReplyKeyboardMarkup @[@[
      KeyboardButton(text: sendContactIntoT, requestContact: some true)
    ]]

    noReply* = newReplyKeyboardRemove(true)


let
    answerBtns* = [
      ("1", "1"),
      ("2", "2"),
      ("3", "3"),
      ("4", "4"),
      ("empty", "0"),
    ].toInlineButtons

    moveBtns* = @[
      ("prev", "prev"),
      ("next", "next"),
    ].toInlineButtons


func timeSerializer*(lastTime: int64): string =
    ""

func answerSheetSerializer*(sheet: seq[int]): string =
    ""
