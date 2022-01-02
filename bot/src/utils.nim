template castSafety*(body): untyped =
  {.cast(gcsafe).}:
    body

#TODO
template tryFor*(body): untyped =
  discard
  