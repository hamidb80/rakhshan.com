import std/[strutils, os]

const
  pageSize* {.intdefine.} = 3
  agents* {.intdefine.} = 2
  agentsTimeOut* {.intdefine.} = 10
  minQuizTime* = 60

let
  dbfPath* = getenv("STORAGE") / "main.db"
  authorChatId* = getenv("AUTHOR_CHAT_ID").parseInt
  tgToken* = getEnv("TG_TOKEN")
  
  
var
  defaultQuestionPhotoUrl* = ""


func findThreadId*(chatid: int64): int64 = 
  chatid mod agents