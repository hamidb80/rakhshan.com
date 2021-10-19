import strutils
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
    addQuizT* = "اضافه کردن آزمون"
    enterQuizNameT* = "نام آزمون را وارد کنید"
    enterQuizTimeT* = "زمان آزمون را وارد کنید"
    enterQuizGradeT* = "پایه تحصیلی آزمون را وارد کنید"
    enterQuizLessonT* = "نام درس آزمون را انتخاب کنید"
    enterQuizChapterT* = "شماره فصل درس آزمون را وارد کنید"
    
    selectQuizT* = "انتخاب آزمون"
    enterQuestionInfoT* = "توضیحات سوال را وارد کنید"
    enterQuestionAnswerT* = "جواب سوال را وارد کنید"

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
      @[selectQuizT]
    ]

    adminReplyRaw = @[ @[addQuizT, removeQuizT]]

    memberReply* = newReplyKeyboardMarkup memberReplyRaw
    adminReply* = newReplyKeyboardMarkup adminReplyRaw & memberReplyRaw

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

