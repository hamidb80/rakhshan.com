import sequtils, strformat, strutils
import telebot, asyncdispatch, logging, options


type 
  TgCtx = ref object 
    chatId: int
    path: string
    state: int

    member: Option[MemberCtx]

  MemberCtx = ref object
    fname: string
    lname: string

  KeyboardAlias = tuple
    text: string
    code: string


tgController(bot: Telebot, ctx: TgCtx): 
  # main templates convert to dirty one

  template goback= ctx.path.pop
  template forward(newp: varargs[string])= ctx.path.push newp

  template sendText= discard # has to be async
  
  template genKeyboard(seq[seq[KeyboardAlias]])= discard
  template removeKeyboard= discard

  proc resovler {.internal.}=
    discard

  route "/"=
    fn

  route "/reshte"=
    genKeyboard  ...

  route ("quiz", @qid[int], "part", @pid[int])=
    discard



const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"


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
  addHandler newConsoleLogger(fmtStr= "$levelname, [$time]")

  let bot = newTeleBot API_KEY
  bot.onUpdate updateHandler


  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: discard