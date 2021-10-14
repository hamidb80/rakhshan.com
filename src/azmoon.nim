import sequtils, tables, strformat, strutils
import telebot, asyncdispatch, logging, options


type
  KeyboardAlias = tuple
    text: string
    code: string



template goback{.dirty.}= uctx.path.pop
template forward(newp: varargs[string]){.dirty.}= uctx.path.push newp

template sendText{.dirty.}= discard # has to be async

proc genKeyboard(aliases: seq[seq[KeyboardAlias]])= discard
proc removeKeyboard= discard

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