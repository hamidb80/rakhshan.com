import sequtils, tables, strformat, strutils, json
import telebot, asyncdispatch, logging, options
import utils/tg

type
  KeyboardAlias = tuple
    text: string
    code: string

# UTILS ------------------------------------

template sendText{.dirty.} = discard # has to be async

proc genKeyboard(aliases: seq[seq[KeyboardAlias]]) = discard
proc removeKeyboard = discard

# APP STATES -----------------------------------

var users: Table[int64, UserCtx]

proc getUser(chatId: int64): UserCtx =
  if chatId notin users:
    users[chatId] = new UserCtx
    users[chatId].chatId = chatId

  return users[chatId]

# ROUTER -----------------------------------

let router = newRouter:
  route() as "home":
    let keys = toseq(1..4).mapit:
      InlineKeyboardButton(text: $it, callbackData: some $it)

    discard await bot.sendMessage(uctx.chatId, "hello",
      parseMode = "markdown",
      replyMarkup = newInlineKeyboardMarkup(keys))


  route(qid: int, pid: int) as "quiz":
    discard

proc findChatId(updateFeed: Update): int64 =
  template findId(msgWrapper): untyped =
    msgWrapper.message.get.chat.id

  return
    if issome updateFeed.message: updateFeed.findId
    elif issome updateFeed.callbackQuery: updateFeed.callbackQuery.get.findId
    else: raise newException(ValueError, "couldn't find chat_id")


proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
  template uctx: untyped =
    getUser findChatId u

  if u.message.issome:
    let msg = u.message.get

    if msg.text.isSome:
      {.cast(gcsafe).}:
        await trigger(router, "home", bot, uctx, u, %*[msg.text.get])

  elif u.callbackQuery.issome:
    let cq = u.callbackQuery.get
    discard await bot.answerCallbackQuery($cq.id, fmt"~~{cq.data.get}~~")
# ---------------------------------------

when isMainModule:
  addHandler newConsoleLogger(fmtStr = "$levelname, [$time]")

  const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  let bot = newTeleBot API_KEY
  bot.onUpdate dispatcher

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: discard
