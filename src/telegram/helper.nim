type
  KeyboardAlias = tuple
    text: string
    code: string

template sendText{.dirty.} = discard

template redirect*(alias, params){.dirty.} =
  trigger(router, alias, bot, uctx, u)


proc genKeyboard(aliases: seq[seq[KeyboardAlias]]) = discard
proc removeKeyboard = discard
