import asyncdispatch
import telebot
import ./controller

template redirect*(alias, params): untyped {.dirty.} =
  trigger(router, alias, bot, uctx, u, params)

template `<<`*(chatid: int64, box: tuple[t: string, k: KeyboardMarkup]): untyped {.dirty.} =
  bot.sendMessage(chatid, box[0], replyMarkup = box[1], parsemode = "MarkdownV2")

template `<<`*(chatid: int64, text: string): untyped{.dirty.} =
  bot.sendMessage(chatid, text, parsemode = "MarkdownV2")

template `<^`*(msginfo: tuple[chatid: int64, msgid: int], box: tuple[t: string, k: KeyboardMarkup]): untyped {.dirty.} =
  bot.editMessageText(box[0], $msginfo[0], msginfo[1], replyMarkup = box[1], parsemode = "MarkdownV2")

template `<^`*(msginfo: tuple[chatid: int64, msgid: int], text: string): untyped{.dirty.} =
  bot.editMessageText(text, $msginfo[0], msginfo[1], parsemode = "MarkdownV2")

template `<!`*(chatid: int64, msgid: int): untyped{.dirty.} =
  bot.deleteMessage($chatId, msgid)

template `/->`*(newStage: Stages): untyped {.dirty.} =
  uctx.stage = newStage

template trySendInvalid*(body) =
  try:
    body
  except:
    discard await chatid << invalidInputT

template myrecord*: untyped =
  uctx.record.get
