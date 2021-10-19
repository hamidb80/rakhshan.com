import asyncdispatch
import telebot
import ./controller

template redirect*(alias, params): untyped {.dirty.} =
  trigger(router, alias, bot, uctx, u, params)

template `<<`*(msgid: int64, box: tuple[t: string, k: KeyboardMarkup]): untyped {.dirty.} =
  bot.sendMessage(msgid, box[0], replyMarkup = box[1])

template `<<`*(msgid: int64, text: string): untyped{.dirty.} =
  bot.sendMessage(msgid, text)

template `/->`*(newStage: Stages): untyped {.dirty.}=
  uctx.stage = newStage
  