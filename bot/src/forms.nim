import std/[strutils]

type
  FormError* = object of CatchableError
  FmRangeError* = object of FormError
  FValueError* = object of FormError

func protectedParseint*(
  s: string, min = 0, max = int.high
): int {.raises: [FormError].} =
  try:
    result = parseint s

  except ValueError:
    raise newException(FValueError, "")

  if result notin min..max:
    raise newException(FmRangeError, "")

func isPhoneNumber*(s: string): bool =
  (s.len in 8 .. 15) and allCharsInSet(s, {'+', '0'..'9'})
