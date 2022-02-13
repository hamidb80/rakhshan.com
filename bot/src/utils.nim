import std/[options, times]
import macros, macroplus

const NotFound* = -1

template `or`*(s1, s2: string): string =
  if s1 == "":
    s2
  else:
    s1

func parseInt*(n: char): int =
  n.ord - '0'.ord

func forget*[T](opt: var Option[T]) =
  opt = none T

proc unixNow*(): int64 =
  getTime().toUnix

func getPercent*(userAnswers, correctAnswers: seq[int]): float =
    var
        corrects = 0
        wrongs = 0
        empties = 0

    for i in 0..userAnswers.high:
        if userAnswers[i] == 0: empties.inc
        elif userAnswers[i] == correctAnswers[i]: corrects.inc
        else: wrongs.inc

    (corrects * 3 - wrongs) / (userAnswers.len * 3) * 100

macro fakeSafety*(def)=
  assert def.kind in RoutineNodes
  let b = def[RoutineBody]
  
  def[RoutineBody] = quote:
    {.cast(gcsafe).}:
      {.cast(noSideEffect).}:
        `b`

  return def