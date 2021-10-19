import 
  sequtils, tables, strformat, strutils, 
  asyncdispatch, options, json
import telebot
import
  telegram/[controller, helper, messages, comfortable],
  # concurrency,
  states, utils

# ROUTER -----------------------------------

const PASS = "1234"


template `->`(newStage: Stages): untyped {.dirty.}=
  uctx.stage = newStage
  

var router = new RouterMap
newRouter(router):
  route(chatid: int, msgtext: string) as "home":
    case msgtext:
    of loginT:
      discard sendmsg(chatid, "good luck!", noReply)

    of adminT:
      -> sEnterAdminPass
      discard sendmsg(chatid, sendAdminPassT, noReply)

    else:
      discard await sendmsg(chatid, mainPageMsg, notLoggedInReply)

  route(chatid: int, pass: string) as "admin-login":
    
    case pass:
    of PASS:
      -> sMemberPage
      discard sendmsg(chatid, loggedInAsAdminT)

    of cancelT:
      -> sMain
      discard await sendmsg(chatid, returningT)
      discard sendmsg(chatid, menuT, adminReply)

    else:
      discard sendmsg(chatid, passwordIsWrongT)

  route() as "test":
    let msg = u.message.get

    if issome msg.photo:
      # NOTE: when you send an image, telegram will send it to the bot with different sizes
      # - you can pick smallest one or biggest one, or save them all
      let fid = msg.photo.get[^1].fileId
      discard await bot.sendPhoto(msg.chat.id, fid)


    let mymsg = await bot.sendPhoto(
      uctx.chatId, fileNameGen "temp/emoji.png",
      "caption",
      replyMarkup = newInlineKeyboardMarkup(answerBtns, moveBtns))

    #------------------------------

    await sleepAsync 500

    discard await bot.editMessageMedia(
      InputMediaPhoto(kind: "photo", media: fileNameGen "temp/share.png"),
      $mymsg.chat.id, mymsg.messageId,
      replyMarkup = newInlineKeyboardMarkup(answerBtns, moveBtns)
    )

  route() as "add-quiz":
    discard

  callbackQuery(chatid: int, buttonText: string) as "quiz-question-controll":
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
    let 
      uctx = getuctx()
      msg = u.message.get

    args.add %msg.chat.id
    args.add %(
      if issome msg.text: msg.text.get
      else: ""
    )

    let route = case uctx.stage:
      of sMain: "home"
      of sEnterAdminPass: "admin-login"
      of sEnterNumber: "..."
      else: raise newException(ValueError, "what?")

    fakeSafety:
      discard await trigger(router, route, bot, uctx, u, args)


  elif u.callbackQuery.issome:
    let cq = u.callbackQuery.get

    fakeSafety:
      let res = await trigger(
        router, "select-quiz", 
        bot, getuctx, u, 
        %*[cq.message.get.chat.id, cq.data.get]
      )

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
    except: echo ">>>> " & getCurrentExceptionMsg()
