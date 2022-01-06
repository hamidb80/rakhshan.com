import macros, db_sqlite
import results, macroplus

func getName(n: NimNode): string =
  case n.kind:
  of nnkPostfix:
    n[1].strVal
  of nnkIdent:
    n.strVal
  else:
    raise newException(ValueError, "cannot get name from node kind: " & $n.kind)

type
  HandledErrorKinds* = enum
    heDbError, heRuntimeError

  HandledError* = object
    kind*: HandledErrorKinds
    exceptionMsg*: string

  RunTimeError* = object of CatchableError

macro errorHandler*(body: untyped): untyped =
  let
    procName = getName(body[RoutineName])
    handlerName = postfix(ident(procName & "Handler"), "*")
    params = RoutineArguments body
    returnType = RoutineReturnType body

    newReturnType = quote: Result[`returnType`, HandledError]

  var callProcWithParams = newCall(procName)
  for p in params:
    callProcWithParams.add p[IdentDefName]

  result = newStmtList()
  result.add body
  result.add quote do:
    proc `handlerName`(): `newReturnType` =
      try:
        result.ok `callProcWithParams`

      except `DbError`:
        result.err HandledError(
          kind: heDbError,
          exceptionMsg: getCurrentExceptionMsg())
        close(db)

      except:
        result.err HandledError(
          kind: heRuntimeError,
          exceptionMsg: getCurrentExceptionMsg())
        close(db)

  for p in params:
    result[^1][RoutineFormalParams].add p

  return result

proc customTryGet*[T](r: Result[T, HandledError]): T =
  if r.isOk: result = r.get
  else:
    let e = r.error()
    case e.kind:
      of heDbError: raise newException(DbError, e.exceptionMsg)
      of heRuntimeError: raise newException(RunTimeError, e.exceptionMsg)
