import asyncdispatch
import telebot
import ./controller

type
  MsgInfo = tuple[chatid: int64, msgid: int]

template redirect*(alias, params): untyped {.dirty.} =
  trigger(router, alias, bot, uctx, u, params)

template `<<`*(chatid: int64, box: tuple[t: string,
    k: KeyboardMarkup]): untyped {.dirty.} =
  bot.sendMessage(chatid, box[0], replyMarkup = box[1],
      parsemode = "MarkdownV2")

template `<<`*(chatid: int64, text: string): untyped {.dirty.} =
  bot.sendMessage(chatid, text, parsemode = "MarkdownV2")

template `<@`*(chatid: int64, box: tuple[url,
    caption: string]): untyped {.dirty.} =
  bot.sendPhoto(chatid, box[0], box[1], parsemode = "MarkdownV2")

template `<@`*(chatid: int64, url: string): untyped {.dirty.} =
  chatid <@ (url, "")

template `<@^`*(msginfo: MsgInfo, newurl: string): untyped {.dirty.} =
  bot.editMessageMedia(newInputMediaPhoto(newurl), $msginfo[0], msgInfo[1])

template `<^`*(msginfo: MsgInfo, box: tuple[t: string,
    k: KeyboardMarkup]): untyped {.dirty.} =
  bot.editMessageText(box[0], $msginfo[0], msginfo[1], replyMarkup = box[1],
      parsemode = "MarkdownV2")

template `<^`*(msginfo: MsgInfo,
    text: string): untyped {.dirty.} =
  bot.editMessageText(text, $msginfo[0], msginfo[1], parsemode = "MarkdownV2")

template `<!`*(chatid: int64, msgid: int): untyped {.dirty.} =
  bot.deleteMessage($chatId, msgid)

template `!!`(stuff): untyped = asyncCheck chatid << stuff
template `!!<<`(stuff): untyped = 
  !! stuff
  debugEcho "START ---", getCurrentExceptionMsg(), "END ---"

template `/->`*(newStage: Stages): untyped {.dirty.} =
  uctx.stage = newStage

template trySendInvalid*(body) =
  try:
    body
  except:
    discard await chatid << invalidInputT

template myrecord*: untyped {.dirty.} =
  uctx.record.get

template isDoingQuiz*: untyped {.dirty.} =
  uctx.record.issome

template adminRequired*(body): untyped {.dirty.} =
  if issome(uctx.membership) and uctx.membership.get.isAdmin == 1:
    body

template qc*: untyped {.dirty.} =
  uctx.quizCreation.get

template qq*: untyped {.dirty.} =
  uctx.quizQuery.get

template qp*: untyped {.dirty.} =
  uctx.queryPaging.get

template `!!`*(chatid, stuff) {.dirty.} =
  asyncCheck chatid << stuff
  debugEcho "START ---", getCurrentExceptionMsg(), "END ---"