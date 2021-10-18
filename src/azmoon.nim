import sequtils, tables, strformat, strutils, json
import telebot, asyncdispatch, options
import telegram/[controller, helper], states, utils

# ROUTER -----------------------------------

let nexPrevBtns = @[
  InlineKeyboardButton(text: "prev", callbackData: some "prev"),
  InlineKeyboardButton(text: "next", callbackData: some "next"),
]

var router = new RouterMap
newRouter(router):
  route() as "home":
    let msg = u.message.get

    if issome msg.photo:
      # NOTE: when you send an image, telegram will send it to the bot with different sizes
      # - you can pick smallest one or biggest one, or save them all
      let fid = msg.photo.get[^1].fileId
      discard await bot.sendPhoto(msg.chat.id, fid)


    let
      keys = toseq(1..4).mapit:
        InlineKeyboardButton(text: $it, callbackData: some $it)

      newkeys = toseq(2..5).mapit:
        InlineKeyboardButton(text: $it, callbackData: some $it)

    let mymsg = await bot.sendPhoto(
      uctx.chatId, fileNameGen "temp/emoji.png",
      "caption",
      replyMarkup = newInlineKeyboardMarkup(keys, nexPrevBtns))

    #------------------------------

    await sleepAsync 500

    discard await bot.editMessageMedia(
    InputMediaPhoto(kind: "photo", media: fileNameGen "temp/share.png"),
    $mymsg.chat.id, mymsg.messageId,
      replyMarkup = newInlineKeyboardMarkup(newkeys, nexPrevBtns)
    )

  route() as "keyboard":
    let keysp = toseq(1..4).mapit KeyboardButton(text: $it)

    discard bot.sendMessage(uctx.chatId, "hello",
      parseMode = "markdown",
      replyMarkup = newReplyKeyboardMarkup(keysp))


  callbackQuery(qid: string, buttonText: string) as "select-quiz":
    return buttonText

# ------------------------------------------

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
    except: echo "--------------\n\n" & getCurrentExceptionMsg() & "\n\n--------------------------"
