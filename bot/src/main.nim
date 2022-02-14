import
  std/[options, json, tables, strutils, random, asyncdispatch, db_sqlite, os]
import telebot, packedArgs
import
  controller, comfortable, settings, router,
  messages, forms, states, utils, database/[queries]


let bot = newTeleBot tgToken
var agentsInput = newseq[Channel[Action]](agents)

# ---------------------------------------

template toFn(name): untyped = router[name]

proc dispatcherImpl*(up: Update, chatId: int64): Action {.fakeSafety.} =
  result = Action(chatid: chatid, args: %*[chatid], update: up)

  let uctx = getOrCreateUser chatid
  if uctx.firstTime:
    uctx.membership = dbworksCapture dbfPath:
      getMember(db, up.getchatid)

    uctx.firstTime = false
    result.handler = toFn reStart

  else:
    if up.message.issome:
      let
        msg = up.message.get
        text = msg.text.get("")

      if text.startsWith("/") and text.len > 2: # it's a command
        result.args.add %text[2..^1]
        result.handler = tofn:
          case text[1]:
          # without argument
          of 's': reStart
          of 'h': reHelp
          of 'z': reReset
          # with arguemnt
          of 'q': reShow_quiz
          of 'a': reAnalyze
          of 'r': reGet_rank
          else: reInvalid_command

      else: # it's a text message
        result.args.add %text

        result.handler = tofn:
          case uctx.stage:
          of sMain: reHome
          of sSendContact: reVerify_user
          of AddQuizStages: reAdd_quiz
          of AddQuestionStages: reAdd_question
          of sEnterMainMenu: reEnter_menu
          of sMainMenu: reMenu
          of FindQuizStages: reFind_quiz
          of DeleteQuiz: reDelete_quiz
          of sTakingQuiz: reMiddle_of_quiz
          of sScroll: reMiddle_of_scroll
          else: reInvalid_command

    elif up.editedMessage.issome:
      result.args.add %up.editedMessage.get.messageId

      result.handler = toFn:
        case uctx.stage:
        of AddQuizStages, AddQuestionStages: reEdit_quiz_creation
        else: raise newException(ValueError,
            "cant edit message when stage is: " & $uctx.stage)

    elif up.callbackQuery.issome:
      let
        cq = up.callbackQuery.get
        cmd = cq.data.get("/d")
        parameter = cmd[2..^1]

      result.handler = toFn:
        case cmd[1]:
        of 't': reTake_quiz
        of 'j': reJump_question
        of 'p': reSelect_answer
        of 'g': reGoto
        of 'm': reScroll
        of 'd': reDont_care
        else: reInvalid_command

      result.args = %*[cq.message.get.chat.id, cq.message.get.messageId, parameter]

    else:
      raise newException(ValueError, "did not any criteria matched")

proc dispatcher*(bot: TeleBot, up: Update): Future[bool] {.async, fakeSafety.} =
  let chatid = findChatId up

  if isSome chatid:
    let chid = chatid.get
    agentsInput[findThreadId chid].send dispatcherImpl(up, chid)

  return true

# app --------------------

proc resultWrapper(a: Action){.async.} =
  try:
    let res = await a.handler(bot, a.update, getOrCreateUser(a.chatid), a.args)

    if issome a.update.callbackQuery:
      asyncCheck bot.answerCallbackQuery($a.update.callbackQuery.get.id, res)

  except DbError: asyncCheck a.chatid << databaseErrorT
  except FValueError: asyncCheck a.chatid << invalidInputT
  except FmRangeError: asyncCheck a.chatid << rangeErrorT
  except: asyncCheck a.chatid << someErrorT

proc agentLoopImpl(ch: ptr Channel[Action], timeout: int) {.async, fakeSafety.} =
  while true:
    await sleepAsync timeout

    while true:
      let (ok, action) = ch[].tryRecv

      if ok: asyncCheck resultWrapper(action)
      else: break

proc agentLoop(ch: ptr Channel[Action], timeout: int) {.packedArgs.} =
  waitfor agentLoopImpl(ch, timeout)

when isMainModule:
  # init DB
  if not fileExists dbfPath:
    echo "not found DB, creating one ..."
    initDatabase dbfPath

  # set default photo
  let m = waitFor authorChatId <@ ("file://" & getCurrentDir() / "assets/no-photo.png")
  defaultPhotoUrl = getBiggestPhotoFileId m

  # register agents, workers, bot, ...
  randomize()

  for i in 0 ..< agents:
    open agentsInput[i]
    discard runThread(agentLoopPacked,
      toAgentLoopArgs(addr agentsInput[i], agentsTimeOut))

  discard runThread(startBackgroudJobPacked,
    toStartBackgroudJobArgs(addr agentsInput, 50))

  bot.onUpdate dispatcher

  # app loop
  while true:
    echo "running ..."
    try: bot.poll(timeout = 100)
    except: echo getCurrentExceptionMsg()
