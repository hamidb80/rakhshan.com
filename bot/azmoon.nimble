# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "a"
license       = "ALL RIGHTS LIMITED"
srcDir        = "src"
bin           = @["main"]


# Dependencies

requires "nim >= 1.6.2"
requires "telebot >= 2022.01.02"
requires "macroplus >= 0.1.4"
requires "asyncanything >= 0.0.4"
requires "result >= 0.2.0"
requires "https://github.com/hamidb80/easydb"

task go, "run app":
  putenv "DB_PATH", "./temp/play.db"
  exec "nim cc -d:ssl --gc:orc -d:goAsyncTimeInterval=20 --run src/main.nim"