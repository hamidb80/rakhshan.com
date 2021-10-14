import tables, sequtils, strformat, options
import macros except params
import
  asyncdispatch, telebot,
  macroplus, macroutils

type
  TgCtx* = ref object
    chatId*: int
    path*: string
    state*: int
    route*: seq[string]
    member*: Option[MemberCtx]

  MemberCtx* = ref object
    fname*: string
    lname*: string

  # RouterProc = proc(bot: Telebot, uctx: TgCtx) {.async.}
  RouterProc = proc() {.async.}
  RouterMap* = Table[string, RouterProc]

template setRoute(vr, ro, fn): untyped =
  newTree(nnkAsgn, [newTree(nnkBracketExpr, [vr, ro]), fn])

macro tgRouter*(varName: untyped, args: varargs[untyped]): untyped =
  result = newStmtList()
  let body = args[^1]

  for entity in body:
    doAssert:
      entity.kind == nnkInfix and
      entity[InfixIdent].strVal == "as"

    let
      aliasName = entity[InfixRightSide].strVal
      fnBody = entity[^1]

    result.add quote do:
      `varname`[`aliasName`] = proc() {.async.} =
        `fnBody`

    # result[^1].params= []

  echo treeRepr result
  echo repr result
  return result

var myname: RouterMap

tgRouter(myname, bot: TeleBot, ctx: string):
  route("/") as "home":
    discard

  route() as "hey":
    echo "DKALJDLKSJ"

# proc dispatcher*(bot: TeleBot, u: Update): Future[bool] {.async.} =
#   if u.message.issome:
#     let msg = u.message.get

#     if msg.text.isSome:
#       let keys = toseq(1..4).mapit InlineKeyboardButton(text: $it,
#           callbackData: some $it)

#       discard await bot.sendMessage(msg.chat.id, msg.text.get,
#         replyToMessageId = msg.messageId,
#         parseMode = "markdown",
#         replyMarkup = newInlineKeyboardMarkup(keys))


#   elif u.callbackQuery.issome:
#     let cq = u.callbackQuery.get
#     discard await bot.answerCallbackQuery($cq.id, fmt"~~{cq.data.get}~~", true)

# proc trigger*(routermap: RouterMap, routeAlias: string, params: seq[string]) =
  # if routeAlias in routermap:
    # routermap[routeAlias](params)

  # raise newException(ValueError, fmt"route alias '{routeAlias}' is not defined")
  # raise newException(ValueError, "route alias '{routeAlias}' is not defined")
