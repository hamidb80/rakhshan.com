# Package

version       = "0.1.0"
author        = "hamidb80"
description   = "a Telegram bot for rakhshan.com exclusivly"
license       = "ALL RIGHTS LIMITED"
srcDir        = "src"
bin           = @["main"]

# Dependencies

requires "nim == 1.6.2"
requires "telebot == 2022.01.07"
requires "jalali_nim == 0.0.2"
requires "packedargs"
requires "macroplus == 0.1.20"
requires "https://github.com/hamidb80/easydb == 0.0.11"

# Commands

task image, "push image | dont forget to write version after the command":
  exec "fandogh image publish --version"

task deploy, "deploy the app":
  exec "fandogh service apply -f fandogh.yml"

task go, "run app for release":
  exec "nim cc --gc:orc -d:useMalloc -d:release --out:bin.exe -d:ssl -d:pageSize=10  src/main.nim"

task dev, "run app in dev mode":
  putenv "AUTHOR_CHAT_ID", "101862091"
  putenv "HOST_API_TOKEN", "okm098QAZ"
  putenv "TG_TOKEN", "2004052302:AAFi_3lrI0dcUa0CRSkVFMD1lBTFyDM_PSs"
  putenv "DB_PATH", "./temp/play.db"
  exec "nim c -d:ssl --gc:orc -d:useMalloc --run src/main.nim "
