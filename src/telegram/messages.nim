import strutils
import telebot
import ./helper

# messages : text that are sent to the client
const
    mainPageMsg* = "‌یکی از گزینه ها رو انتخاب کنید‌"

# texts: texts that are recieved from the client
const
    loginText* = "ورود"
    adminLoginText* = "ادمین"

    askPasswordAdmin* = "رمز ادمین را وارد کنید"


let
    notLoggedInkeyboard* = newReplyKeyboardMarkup @[
        @[adminLoginText],
        @[loginText],
    ]

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

