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


var router = new RouterMap
newRouter(router):
  route(chatid: int, msgtext: string) as "home":
    case msgtext:
    of loginT:
      discard chatid << ("good luck!", noReply)

    of adminT:
      /-> sEnterAdminPass
      discard chatid << (sendAdminPassT, noReply)

    else:
      discard await chatid << (selectOptionsT, notLoggedInReply)

  route(chatid: int, pass: string) as "admin-login":

    case pass:
    of PASS:
      /-> sMenu
      discard chatid << loggedInAsAdminT

    of cancelT:
      /-> sMain
      discard await chatid << returningT
      discard chatid << (menuT, adminReply)

    else:
      discard chatid << passwordIsWrongT

  route(chatid: int, input: string) as "menu":
    case input:
    of addQuizT:
      /-> sAddQuiz
      discard redirect("add-quiz", %[%chatid, %""])
    of removeQuizT: discard
    of selectQuizT: discard
    else:
      discard chatid << wrongCommandT

  route(chatid: int, input: string) as "add-quiz":
    template myquiz: untyped = uctx.quizCreation.get
    template trycode(body) =
      try:
        body
      except:
        discard await chatid << invalidInputT

    case uctx.stage:
    of sAddQuiz:
      /-> sAQEnterName
      uctx.quizCreation = some QuizCreate()
      discard chatid << enterQuizNameT

    of sAQEnterName:
      myquiz.name = input
      /-> sAQTime
      discard chatid << enterQuizTimeT

    of sAQTime: # TODO parse time rather than giving a number in seconds
      trycode:
        myquiz.time = input.parseInt
        /-> sAQgrade
        discard chatid << enterQuizGradeT

    of sAQgrade:
      trycode:
        myquiz.grade = input.parseInt
        /-> sAQLesson
        discard chatid << enterQuizLessonT

    of sAQLesson:
      myquiz.lesson = input
      /-> sAQchapter
      discard chatid << enterQuizChapterT

    of sAQchapter:
      trycode:
        myquiz.chapter = input.parseInt
        /-> sAQQuestion
        discard redirect("add-quiestion", %[%chatid, %""])

    else: 
      discard chatid << wrongCommandT

  route(chatid: int, input: string) as "add-question":
    discard

  route() as "give-image":
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
      of sAddQuiz: "add-quiz"
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
