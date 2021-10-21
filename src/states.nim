import 
  tables, times, options,
  locks, os, asyncdispatch
import telegram/[controller], database/models, utils

type 
  NotificationKinds* = enum
    nkEndQuizTime, nkUpdateQuizTime,

  Notification* = object
    kind*: NotificationKinds
    quiz_id*: int64
    user_chat_id*: int64
    # msg: string

const 
  maxActivityTimeout = 60 * 60
  minResreshTimeSeconds = 10 

var
  users: Table[int64, UserCtx]
  notifier*: Channel[Notification]
  usersLock: Lock


proc getOrCreateUser*(chatId: int64): UserCtx =
  withLock usersLock:
    if chatId notin users:
      users[chatId] = new UserCtx
      users[chatId].chatId = chatId

    return users[chatId]

proc startTimer*(delay: int) {.thread.}=
  fakeSafety:
    while true:
      var offlineUsers: seq[int64]
      let currentTime = now()

      # delete offline users
      for (uid, user) in users.pairs:
        let dt = (currentTime - user.lastActivity).inSeconds
        if dt > maxActivityTimeout: # TODO and the time is greater than quiztime
          offlineUsers.add uid

      withLock usersLock:
        for uid in offlineUsers: 
          del users, uid

      # update quizzes times
      var timeChanging: seq[int]
      withLock usersLock:
        for (uid, user) in users.pairs:
          if isnone user.record: continue
          let 
            freshNow = now()
            record = user.record.get
            quiz = record.quiz
            dtStart = (freshNow - record.startTime).inSeconds
            dtLastCheck = (freshNow - record.lastCheckedTime).inSeconds

          if dtStart >= quiz.time:
            notifier.send Notification(kind:nkEndQuizTime, quizid: quiz.id, userchatid: uid)

          elif dtLastCheck > minResreshTimeSeconds:
            record.lastCheckedTime = freshNow
            notifier.send Notification(kind:nkUpdateQuizTime, quizid: quiz.id, userchatid: uid)

      sleep delay


notifier.open
initLock usersLock