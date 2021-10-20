import 
  tables, times,
  locks, threadpool, os
import telegram/[controller], database/models

type 
  NotificationKinds = enum
    nkEndQuizTime, nkUpdateQuizTime,

  Notification* = object
    kind: NotificationKinds
    quiz_id: int
    user_chat_id: int
    
    valueInt: int

var
  users: Table[int64, UserCtx]
  usersLock: Lock

  questionsCache: Table[int64, Table[int64, QuestionModel]]
  questionsLock: Lock

  notifier: Channel[Notification]

proc getOrCreateUser*(chatId: int64): UserCtx =
  withLock usersLock:
    if chatId notin users:
      users[chatId] = new UserCtx
      users[chatId].chatId = chatId

    return users[chatId]

const maxActivityTimeout = 60 

proc startTimer*(delay: int) {.thread.}=
  while true:
    let currentTime = now()
    var offlineUsers: seq[int]
    
    withLock usersLock:
      # TODO: update quizzes times

      for (uid, user) in users.pairs:
        if (currentTime - userlastActivity).inMinutes > maxActivityTimeout:
          offlineUsers.add uid

      # delete offline users
      for uid in offlineUsers: 
        del users[uid]


    sleep delay

proc getQuestion*(quizid, questionId: int64): QuestionModel =
  withLock questionsLock:
    discard


notifier.open
initLock usersLock
initLock questionsLock