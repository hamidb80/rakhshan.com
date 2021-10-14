import macros
# import macroutils


macro tgController*(bot, contextArg, body)=
  echo body.treeRepr
  echo "------------------------"

  for node in body:
    if node.kind == nnkTemplateDef:
      node.addPragma newIdentNode "dirty"

  echo body.treeRepr

  body


template nothing {.dirty.}= discard # has to be async

expandMacros:
  tgController(bot, ctx: object):
    template sendText{.me.}= discard # has to be async
