template fakeSafety*(body): untyped =
  {.cast(gcsafe).}:
    body
