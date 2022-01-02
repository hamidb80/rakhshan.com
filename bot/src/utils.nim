template castSafety*(body): untyped =
  {.cast(gcsafe).}:
    body

#TODO
template tryFor*(body): untyped =
  discard

template `or`*(s1, s2: string): string =
  if s1 == "":
    s2
  else:
    s1

func parseInt*(n: char): int =
  n.ord - '0'.ord
