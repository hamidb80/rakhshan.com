import sequtils, tables, strformat, strutils
import telebot, asyncdispatch, logging, options


type 
  TgCtx = ref object 
    chatId: int
    path: string
    state: int
    route: seq[string]
    member: Option[MemberCtx]

  MemberCtx = ref object
    fname: string
    lname: string

  KeyboardAlias = tuple
    text: string
    code: string

  RouterMap = Table[
    string, 
    proc(bot: Telebot, uctx: TgCtx){.async, nimcall.}
  ]


template goback{.dirty.}= uctx.path.pop
template forward(newp: varargs[string]){.dirty.}= uctx.path.push newp

template sendText{.dirty.}= discard # has to be async

proc genKeyboard(aliases: seq[seq[KeyboardAlias]])= discard
proc removeKeyboard= discard

proc dispatcher(bot: TeleBot, u: Update): Future[bool] {.async.}=
  if u.message.issome:
    let msg = u.message.get

    if msg.text.isSome:
      let keys = toseq(1..4).mapit InlineKeyboardButton(text: $it, callbackData: some $it)

      discard await bot.sendMessage(msg.chat.id, msg.text.get,
        replyToMessageId = msg.messageId,
        parseMode = "markdown",
        replyMarkup = newInlineKeyboardMarkup(keys))


  elif u.callbackQuery.issome:
      let cq = u.callbackQuery.get
      discard await bot.answerCallbackQuery($cq.id, fmt"~~{cq.data.get}~~", true)


proc trigger(route: seq[string] or varargs[string])=
  #TODO check get keys at compile time
  discard


const router: RouterMap = tgRouter(bot: Telebot, uctx: TgCtx): 
  route("/") as "home":
    discard

  route("/reshte") as "select-reshte":
    discard

  route("quiz", @qid[int], "part", @pid[int]) as "quiz":
    discard



when isMainModule:
  addHandler newConsoleLogger(fmtStr= "$levelname, [$time]")

  const API_KEY = "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  let bot = newTeleBot API_KEY
  bot.onUpdate dispatcher

  while true:
    echo "running ..."

    try: bot.poll(timeout = 100)
    except: discard