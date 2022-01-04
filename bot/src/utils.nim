import options
import results

const NotFound* = -1

template castSafety*(body): untyped =
  {.cast(gcsafe).}:
    body

template `or`*(s1, s2: string): string =
  if s1 == "":
    s2
  else:
    s1

func parseInt*(n: char): int =
  n.ord - '0'.ord

func forget*[T](opt:var Option[T])=
  opt = none T