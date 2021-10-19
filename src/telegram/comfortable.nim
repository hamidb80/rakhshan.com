import asyncdispatch
import telebot

template redirect*(alias, params){.dirty.} =
  trigger(router, alias, bot, uctx, u)

template sendmsg*(msgid: int64, text: string, rmarkup: KeyboardMarkup = nil): untyped{.dirty.} =
  bot.sendMessage(msgid, text, replyMarkup = rmarkup)
