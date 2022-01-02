import os, sequtils, options
import telebot

# ------------------------------------------

func toInlineButtons*(
  buttons: openArray[tuple[text, code: string]]
): seq[InlineKeyboardButton] =
  buttons.mapIt:
    InlineKeyboardButton(text: it.text, callbackData: some it.code)

func toKeyboardButtons*(btntexts: openArray[string]): seq[KeyboardButton] =
  btntexts.mapIt KeyboardButton(text: it)

func newInlineKeyboardMarkup*(
  keyboards: seq[seq[InlineKeyBoardButton]]
): InlineKeyboardMarkup =
  result = newInlineKeyboardMarkup()
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

# ------------------------------------------

func getChatId(msg: Message): int64 =
  msg.chat.id

func getChatId*(u: Update): int64 =
  if issome u.message:
    getChatId u.message.get
  elif isSome u.editedMessage:
    getChatId u.message.get
  elif issome u.callbackQuery:
    u.callbackQuery.get.fromUser.id
  else:
    raise newException(ValueError, "not supported")

# ------------------------------------------

func getBiggestPhotoFileId*(msg: Message): string =
  # NOTE: when you send an image, telegram will send it to the bot with different sizes
  # - you can pick smallest one or biggest one, or save them all
  msg.photo.get[^1].fileId

proc findChatId*(updateFeed: Update): int64 =
  template findId(msgWrapper): untyped =
    msgWrapper.message.get.chat.id

  return
    if issome updateFeed.message: updateFeed.findId
    elif issome updateFeed.callbackQuery: updateFeed.callbackQuery.get.findId
    else: raise newException(ValueError, "couldn't find chat_id")