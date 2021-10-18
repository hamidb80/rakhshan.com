import sequtils, tables, strformat, strutils, json
import telebot, asyncdispatch, logging, options
import telegram/[controller], states, utils

# ROUTER -----------------------------------

var router = new RouterMap
newRouter(router):
  route() as "home":
    let keys = toseq(1..4).mapit:
      InlineKeyboardButton(text: $it, callbackData: some $it)

    discard bot.sendMessage(uctx.chatId, "hello",
      parseMode = "markdown",
      replyMarkup = newInlineKeyboardMarkup(keys))

    #------------------------------
    await sleepAsync 1

    let keysp = toseq(1..4).mapit KeyboardButton(text: $it)

    discard bot.sendMessage(uctx.chatId, "hello",
      parseMode = "markdown",
      replyMarkup = newReplyKeyboardMarkup(keysp))


  callbackQuery(qid: int, buttonText: string) as "select-quiz":
    echo qid


proc findChatId(updateFeed: Update): int64 =
  template findId(msgWrapper): untyped =
    msgWrapper.message.get.chat.id

  return
    if issome updateFeed.message: updateFeed.findId
    elif issome updateFeed.callbackQuery: updateFeed.callbackQuery.get.findId
    else: raise newException(ValueError, "couldn't find chat_id")


proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
  var args = newJArray()
  template getuctx: untyped =
    fakeSafety: getOrCreateUser findChatId u

  if u.message.issome:
    let msg = u.message.get
    var uctx = getuctx()

    if msg.text.isSome:
      let route = case uctx.stage:
        of sMain: "home"
        of sEnterNumber: "..."
        else: raise newException(ValueError, "what?")

      fakeSafety:
        discard await trigger(router, route, bot, uctx, u, args)

  elif u.callbackQuery.issome:
    let cq = u.callbackQuery.get

    fakeSafety:
      let res = await trigger(router, "select-quiz", bot, getuctx, u, %*[cq.id, cq.data.get])

    discard await bot.answerCallbackQuery($cq.id, res)

# ---------------------------------------

when isMainModule:
  # addHandler newConsoleLogger(fmtStr = "$levelname, [$time]")

  const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  let bot = newTeleBot API_KEY
  bot.onUpdate dispatcher

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: discard
