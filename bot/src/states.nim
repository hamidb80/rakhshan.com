import std/[options, locks, times, os]
import controller, database/models, utils, router, settings

type
  UserInfoPair* = tuple[chatid: int64, ctx: UserCtx]

const
  minResreshTimeSeconds = 10

var
  activeUsers = newSeq[seq[UserInfoPair]](agents)
  usersLock = newseq[Lock](agents)

proc getOrCreateUser*(chatId: int64): UserCtx =
  let tid = findthreadid chatid
  withLock usersLock[tid]:
    for au in activeUsers[tid]:
      if au.chatid == chatId:
        result = au.ctx
        break

    if result == nil:
      result = UserCtx(chatId: chatId, firstTime: true)
      activeUsers[tid].add (chatId, result)


proc startBackgroudJob*(agentsInput: ptr seq[Channel[Action]], delay: int) {.thread, fakeSafety.} =
  while true:
    for (tid, localThreadUsers) in activeUsers.pairs:
      # TODO make experiment | access a esizing seq from different threads
      for (chid, user) in localThreadUsers:
        if issome user.record:
          let record = user.record.get

          if record.isReady and not record.isEnded:
            let
              freshNow = now()
              quiz = record.quiz
              dtStart = (freshNow - record.startTime).inSeconds
              dtLastCheck = (freshNow - record.lastCheckedTime).inSeconds

            if dtStart >= quiz.time:
              record.isEnded = true
              agentsInput[tid].send Action(handler: router[reEndquiz], chatid: chid)

            elif dtLastCheck > minResreshTimeSeconds:
              record.lastCheckedTime = freshNow
              agentsInput[tid].send Action(handler: router[reUpdatetimer], chatid: chid)

    sleep delay


# init env --------------
for ul in usersLock.mitems:
  initLock ul
