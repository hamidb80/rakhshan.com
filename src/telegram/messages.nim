import strutils
import telebot
import ./helper

# messages : text that are sent to the client
const
    mainPageMsg* = "‌یکی از گزینه ها رو انتخاب کنید‌"

# texts: texts that are recieved from the client
const
    cancelT* = "انصراف"
    wrongCommandT* = "دستور اشتباه"
    returningT* = "بازگشت ..."
    menuT* = "منو"
    loginT* = "ورود"
    adminT* = "ادمین"

    sendAdminPassT* = "رمز را وارد کنید"
    passwordIsWrongT* = "رمز اشتباه است"
    loggedInAsAdminT* = "به عنوان ادمین وارد شدید"

    addQuizT* = "اضافه کردن آزمون"
    removeQuizT* = "حذف آزمون"
    
    selectQuizT* = "انتخاب آزمون"

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

