import asyncdispatch
import telebot
import ./controller

template redirect*(alias, params){.dirty.} =
  trigger(router, alias, bot, uctx, u)

template sendmsg*(msgid: int64, text: string, rmarkup: KeyboardMarkup = nil): untyped{.dirty.} =
  bot.sendMessage(msgid, text, replyMarkup = rmarkup)

template `<<`*(msgid: int64, text: string): untyped{.dirty.} =
  bot.sendMessage(msgid, text)

template `/->`*(newStage: Stages): untyped {.dirty.}=
  uctx.stage = newStage
  