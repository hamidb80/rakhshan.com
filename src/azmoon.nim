import sequtils, tables, strformat, strutils, json
import telebot, asyncdispatch, logging, options
import utils/tg

type
  KeyboardAlias = tuple
    text: string
    code: string

template sendText{.dirty.} = discard # has to be async

proc genKeyboard(aliases: seq[seq[KeyboardAlias]]) = discard
proc removeKeyboard = discard

let router = newRouter:
  route() as "home":
    let keys = toseq(1..4).mapit:
      InlineKeyboardButton(text: $it, callbackData: some $it)

    discard await bot.sendMessage(uctx.chatId, "hello",
      # replyToMessageId = msg.messageId,
      parseMode = "markdown",
      replyMarkup = newInlineKeyboardMarkup(keys))


  route(qid: int, pid: int) as "quiz":
    discard

var users: Table[int64, UserCtx]

proc getUser(chatId: int64): UserCtx =
  if chatId notin users:
    users[chatId] = new UserCtx
    users[chatId].chatId = chatId

  return users[chatId]

proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
  if u.message.issome:
    let msg = u.message.get

    if msg.text.isSome:
      {.cast(gcsafe).}:
        await trigger(router, "home", bot, getUser msg.chat.id, u, %*[msg.text.get])

  elif u.callbackQuery.issome:
    let cq = u.callbackQuery.get
    discard await bot.answerCallbackQuery($cq.id, fmt"~~{cq.data.get}~~")


when isMainModule:
  addHandler newConsoleLogger(fmtStr = "$levelname, [$time]")

  const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  let bot = newTeleBot API_KEY
  bot.onUpdate dispatcher

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: discard
