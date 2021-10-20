# Package

version       = "0.1.0"
author        = "hamidb80"
description   = "A new awesome nimble package"
license       = "ALL RIGHTS LIMITED"
srcDir        = "src"
bin           = @["azmoon"]


# Dependencies

requires "nim >= 1.5.1"
requires "telebot >= 1.0.10"
requires "macroplus >= 0.1.4"
requires "https://github.com/hamidb80/easydb"

task go, "run app":
  exec "nim r -d:ssl --threads:on src/azmoon.nim"