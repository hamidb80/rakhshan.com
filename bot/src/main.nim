import
  std/[tables, strutils, options, json, random,
  asyncdispatch, threadpool, db_sqlite, os]
import telebot
import
  controller, comfortable,
  settings, router,
  states, utils, database/[queries]


let bot = newTeleBot tgToken
var agentsInput = newseq[Channel[Action]](agents)

# -------------------

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


# FIXME
# asyncCheck bot.answerCallbackQuery($cq.id, res)

# except DbError: chatid !! databaseErrorT
# except FValueError: asyncCheck chatid << invalidInputT
# except FmRangeError: asyncCheck chatid << rangeErrorT
# except: chatid !! someErrorT

# app --------------------

proc agentLoopImpl(ch: ptr Channel[Action], timeout: int) {.async, fakeSafety.} =
  while true:
    await sleepAsync timeout

    while true:
      let (ok, action) = ch[].tryRecv

      if ok:
        let us = getOrCreateUser(action.chatid)
        asyncCheck action.handler(bot, action.update, us, action.args)

      else:
        break

proc agentLoop(ch: ptr Channel[Action], timeout: int) {.fakeSafety.} =
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
    spawn agentLoop(addr agentsInput[i], agentsTimeOut)

  spawn startBackgroudJob(addr agentsInput, 50)
  bot.onUpdate dispatcher

  # app loop
  while true:
    echo "running ..."
    try: bot.poll(timeout = 100)
    except: echo " " & getCurrentExceptionMsg()


# FIXME use thread instead of spawn
