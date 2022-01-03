import result, macroplus, macros

func getName(n: NimNode): string =
  case n.kind:
  of nnkPostfix:
    n[1].strVal
  of nnkIdent:
    n.strVal
  else:
    raise newException(ValueError, "cannot get name from node kind: " & $n.kind)


macro errorHandler*(body: untyped): untyped =
  let
    procName = getName(body[RoutineName])
    handlerName = postfix(ident(procName & "Handler"), "*")
    params = RoutineArguments body
    returnType = RoutineReturnType body

    newReturnType = quote: Result[`returnType`, string]

  var callProcWithParams = newCall(procName)
  for p in params:
    callProcWithParams.add p[IdentDefName]

  result = newStmtList()
  result.add body
  result.add quote do:
    proc `handlerName`(): `newReturnType` =
      try:
        result.ok `callProcWithParams`
      except:
        result.err getCurrentExceptionMsg()

  for p in params:
    result[^1][RoutineFormalParams].add p

  # echo repr result
  # echo "--------------"
  return result

# test:
# func doOp(a: int, b: bool): float {.errorHandler.} =
#   if a <= 5: a.toFloat
#   else: raise newException(ValueError, "more than 5 ??") 
# 
# func doOpHandler(a: int, b: bool): Result[float, string] =
#   try:
#     result.ok doOp(a, b)
#   except:
#     result.err getCurrentExceptionMsg()
