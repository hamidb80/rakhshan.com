type 
  TgCtx = ref object 
    chatId: int
    path: string
    state: int

    member: Option[MemberCtx]

  MemberCtx = ref object
    fname: string
    lname: string


tgController(bot: Telebot, ctx: TgCtx): # has to be async
  template goback= ctx.path.pop
  template go(newp: varargs[string])= ctx.path.push newp

  template sendText= discard

  proc resovler=
    discard

  route "/":
    do: 
      discard

    keyboard(ctx, ): [
      if 
    ]


  route "/exist":
    goBack


import sequtils, strformat, strutils
import telebot, asyncdispatch, logging, options

const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"


var L = newConsoleLogger(fmtStr = "$levelname, [$time] ")
addHandler(L)


proc updateHandler(bot: Telebot, u: Update): Future[bool] {.async.} =
  if u.message.isNone:
    if  u.callbackQuery.issome:
      echo "====================="
      let cq = u.callbackQuery.get
      discard await bot.answerCallbackQuery($cq.id, fmt"~~{cq.data.get}~~", true)
      echo "====================="

    else:
      discard

  elif u.message.get.text.isSome:
    var response = u.message.get

    let keys = toseq(1..4).mapit InlineKeyboardButton(text: $it, callbackData: some $it)

    discard await bot.sendMessage(response.chat.id, response.text.get,
      replyToMessageId = response.messageId,
      parseMode = "markdown",
      replyMarkup = newInlineKeyboardMarkup(keys))


when isMainModule:
  let bot = newTeleBot API_KEY
  bot.onUpdate updateHandler

  while true:
    echo "hello"

    try: bot.poll(timeout = 100)
    except: discard