import os, sequtils, options
import telebot


proc fileNameGen*(path: string): string =
  "file://" & getCurrentDir() / path


func toInlineButtons*(buttons: openArray[tuple[text, code: string]]): seq[
    InlineKeyboardButton] =
  buttons.mapIt:
    InlineKeyboardButton(text: it.text, callbackData: some it.code)

func toKeyboardButtons*(btntexts: openArray[string]): seq[KeyboardButton] =
  btntexts.mapIt KeyboardButton(text: it)



func newInlineKeyboardMarkup*(
  keyboards: seq[seq[InlineKeyBoardButton]]
): InlineKeyboardMarkup =
  new(result)
  result.type = kInlineKeyboardMarkup
  result.inlineKeyboard = keyboards



func newReplyKeyboardMarkup*(
  keyboards: seq[seq[KeyboardButton]]
): ReplyKeyboardMarkup =
  new(result)
  result.type = kReplyKeyboardMarkup
  result.keyboard = keyboards

func newReplyKeyboardMarkup*(
  keyboards: seq[seq[string]]
): ReplyKeyboardMarkup =
  newReplyKeyboardMarkup:
    keyboards.mapit it.mapIt initKeyBoardButton(it)
