import tables
import telegram/[controller]

var users*: Table[int64, UserCtx]

proc getOrCreateUser*(chatId: int64): UserCtx =
  if chatId notin users:
    users[chatId] = new UserCtx
    users[chatId].chatId = chatId

  return users[chatId]