# Package

version       = "0.0.1"
author        = "hamidb80"
description   = "a"
license       = "ALL RIGHTS LIMITED"
srcDir        = "src"
bin           = @["main"]


# Dependencies

requires "nim >= 1.6.2"
requires "telebot >= 1.0.10"
requires "macroplus >= 0.1.4"
# requires "result >= 0.2.0"

requires "https://github.com/hamidb80/easydb"
requires "https://github.com/hamidb80/asyncanything"

task go, "run app":
  exec "nim r -d:ssl src/main.nim"