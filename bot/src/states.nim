import std/[options, locks, times, os]
import telegram/controller, ./database/models,  ./utils

type
  NotificationKinds* = enum
    nkEndQuizTime, nkUpdateQuizTime

  Notification* = object
    kind*: NotificationKinds
    quiz_id*: int64
    user_chat_id*: int64

  UserInfoPair* = tuple[chatid: int64, ctx: UserCtx]

const
  minResreshTimeSeconds = 10

var
  activeUsers: seq[UserInfoPair]
  notifier*: Channel[Notification]
  usersLock: Lock


proc getOrCreateUser*(chatId: int64): UserCtx =
  withLock usersLock:
    for au in activeUsers:
      if au.chatid == chatId:
        result = au.ctx
        break

    if result == nil:
      result = UserCtx(chatId: chatId, firstTime: true)
      activeUsers.add (chatId, result)


proc startTimer*(delay: int) {.thread, fakeSafety.} =
  while true:
    var myActiveUsers: seq[UserInfoPair]

    withLock usersLock:
      myActiveUsers = activeUsers

    for (uid, user) in myActiveUsers:
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
            notifier.send Notification(kind: nkEndQuizTime,
                quizid: quiz.id, userchatid: uid)

          elif dtLastCheck > minResreshTimeSeconds:
            record.lastCheckedTime = freshNow
            notifier.send Notification(kind: nkUpdateQuizTime,
              quizid: quiz.id, userchatid: uid)

    sleep delay


# init env --------------
notifier.open
initLock usersLock
