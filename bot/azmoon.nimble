# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "a Telegram bot for rakhshan.com exclusivly"
license       = "ALL RIGHTS LIMITED"
srcDir        = "src"
bin           = @["main"]


# Dependencies

requires "nim >= 1.6.2"
requires "telebot >= 2022.01.02"
requires "macroplus >= 0.1.4"
requires "asyncanything >= 0.0.4"
requires "result >= 0.2.0"
requires "jalali_nim >= 0.0.2"
requires "https://github.com/hamidb80/easydb"

task dev, "run app":
  putenv "AUTHOR_CHAT_ID", "101862091"
  putenv "HOST_API_TOKEN", "okm098QAZ"
  putenv "TG_TOKEN", "2004052302:AAHm_oICftfs5xLmY0QwGVTE3o-gYgD6ahw"
  putenv "DB_PATH", "./temp/play.db"
  exec "nim cc -d:ssl --gc:arc -d:goAsyncTimeInterval=20 --run src/main.nim"

task go, "run app":
  exec "nim cc -d:ssl -d:release --gc:arc -d:goAsyncTimeInterval=20 --run src/main.nim"