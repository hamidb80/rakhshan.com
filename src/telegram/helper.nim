import os

type
  KeyboardAlias = tuple
    text: string
    code: string


proc fileNameGen*(path: string): string =
  "file://" & getCurrentDir() / path


template redirect*(alias, params){.dirty.} =
  trigger(router, alias, bot, uctx, u)


proc genKeyboard(aliases: seq[seq[KeyboardAlias]]) = discard
proc removeKeyboard = discard
