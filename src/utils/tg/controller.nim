import tables, sequtils, options, json
import macros except params
import
  asyncdispatch, telebot,
  macroplus

type
  TgCtx* = ref object
    chatId*: int
    path*: string
    state*: int
    stage*: int
    member*: Option[MemberCtx]

  MemberCtx* = ref object
    fname*: string
    lname*: string

  RouterProc = proc(bot: Telebot, uctx: TgCtx, args: JsonNode) {.async.}
  RouterMap* = Table[string, RouterProc]


# helper
proc add(father: NimNode; children: openArray[NimNode]): NimNode =
  for node in children:
    father.add node

  return father


proc typeToJsonProc(`type`: string): NimNode =
  return case `type`:
    of "string": bindsym "getStr"
    of "int": bindsym "getInt"
    else:
      raise newException(ValueError, "type not found")

proc extractArgsFromJson(args: openArray[NimNode]): NimNode =
  doassert args.allIt it.kind == nnkExprColonExpr
  result = newStmtList()

  for (index, arg) in args.pairs:
    discard result.add newLetStmt(
      arg[0],
      newcall(
        typeToJsonProc arg[1].strval,
        newNimNode(nnkBracketExpr).add(ident "args", newIntLitNode index)
    ))


macro initRouter(varName: typed, args: varargs[untyped]): untyped =
  result = newStmtList()
  let body = 
    if args[^1].kind != nnkStmtList: args[^1]
    else: args[^1][0]

  for entity in body:
    doAssert:
      entity.kind == nnkInfix and
      entity[InfixIdent].strVal == "as"

    let
      aliasName = entity[InfixRightSide].strVal
      procBody = entity[^1]
      customArgs = entity[1][1..^1]
      commonArgs = args[0..^2] & @[newColonExpr(ident "args",
          bindsym "JsonNode")]
      extractArgs = extractArgsFromJson(customArgs)

    result.add quote do:
      `varname`[`aliasName`] = proc() {.async.} =
        `extractArgs`
        `procBody`

    let paramList = result[^1][3][RoutineFormalParams]
    discard paramList.add commonArgs.mapIt newIdentDefs(it[0], it[1])


  # echo treeRepr result
  # echo repr result
  return result

template newRouter*(body: untyped): var RouterMap=
  var result: RouterMap
  initRouter(result, bot: TeleBot, ctx: TgCtx): body
  result

# var result: RouterMap

# initRouter(result, bot: TeleBot, ctx: TgCtx):
#   route(id: int) as "home":
#     discard

#   route() as "hey":
#     echo "DKALJDLKSJ"

## usage
var tgRouter = newRouter:
  route(id: int) as "home":
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
