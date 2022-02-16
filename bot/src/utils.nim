import std/[times, sequtils, options, macros]
import macroplus, telebot


const NotFound* = -1

template `or`*(s1, s2: string): string =
  if s1 == "":
    s2
  else:
    s1

func parseInt*(n: char): int =
  n.ord - '0'.ord

func forget*[T](opt: var Option[T]) =
  opt = none T

proc unixNow*(): int64 =
  getTime().toUnix

func getPercent*(userAnswers, correctAnswers: seq[int]): float =
  var
    corrects = 0
    wrongs = 0
    empties = 0

  for i in 0..userAnswers.high:
    if userAnswers[i] == 0: empties.inc
    elif userAnswers[i] == correctAnswers[i]: corrects.inc
    else: wrongs.inc

  (corrects * 3 - wrongs) / (userAnswers.len * 3) * 100

macro fakeSafety*(def) =
  assert def.kind in RoutineNodes
  let b = def[RoutineBody]

  def[RoutineBody] = quote:
    {.cast(gcsafe).}:
      {.cast(noSideEffect).}:
        `b`

  return def

# ------------------------------------------

func toInlineButtons*(buttons: openArray[tuple[text, code: string]]
): seq[InlineKeyboardButton] =
  buttons.mapIt:
    InlineKeyboardButton(text: it.text, callbackData: some it.code)

func toKeyboardButtons*(btntexts: openArray[string]): seq[KeyboardButton] =
  btntexts.mapIt KeyboardButton(text: it)

func newInlineKeyboardMarkup*(keyboards: seq[seq[InlineKeyBoardButton]]
): InlineKeyboardMarkup =
  result = newInlineKeyboardMarkup()
  result.inlineKeyboard = keyboards

func newReplyKeyboardMarkup*(keyboards: seq[seq[KeyboardButton]]
): ReplyKeyboardMarkup =
  new(result)
  result.kind = kReplyKeyboardMarkup
  result.keyboard = keyboards

func newReplyKeyboardMarkup*(keyboards: seq[seq[string]]
): ReplyKeyboardMarkup =
  newReplyKeyboardMarkup:
    keyboards.mapit it.mapIt initKeyBoardButton(it)

func newReplyKeyboardMarkupEveryRow*(
  btns: seq[string], columns = 1
  ): ReplyKeyboardMarkup =
  var acc: seq[seq[string]]

  for i, txt in btns:
    if i mod columns == 0:
      acc.add @[txt]
    else:
      acc[^1].add txt

  newReplyKeyboardMarkup acc

template toRKeyboard*(s): untyped =
  newReplyKeyboardMarkupEveryRow s

# ------------------------------------------

func getChatId(msg: Message): int64 =
  msg.chat.id

func getChatId*(u: Update): int64 =
  if issome u.message:
    getChatId u.message.get
  elif isSome u.editedMessage:
    getChatId u.message.get
  elif issome u.callbackQuery:
    u.callbackQuery.get.fromUser.id
  else:
    raise newException(ValueError, "not supported")

# ------------------------------------------

func getBiggestPhotoFileId*(msg: Message): string =
  # NOTE: when you send an image, telegram will send it to the bot with different sizes
  # - you can pick smallest one or biggest one, or save them all
  msg.photo.get[^1].fileId

func getVideoFileId*(maybeMsg: Option[Message]): Option[string] =
  if issome(maybeMsg) and issome(maybeMsg.get.video):
    result = some maybeMsg.get.video.get.fileid

proc findChatId*(u: Update): Option[int64] =
  template findMsgChatId(msgWrapper, msgAlias): untyped =
    some msgWrapper.msgAlias.get.chat.id

  if issome u.message: u.findMsgChatId(message)
  elif issome u.editedMessage: u.findMsgChatId(editedMessage)
  elif issome u.callbackQuery: u.callbackQuery.get.findMsgChatId(message)
  else: none int64

# ------------------------------

template runThread*(prc, args): untyped =
  var th: Thread[typeof args]
  th.createThread(prc, args)
  th
