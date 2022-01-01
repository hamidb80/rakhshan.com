template castSafety*(body): untyped =
  {.cast(gcsafe).}:
    body
