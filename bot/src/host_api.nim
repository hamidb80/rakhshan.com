import asyncdispatch, httpclient

proc sendPhoneNumber*(phoneNumber: string) {.async.} =
  discard

proc verifyPhoneNumber*(phoneNumber: string): Future[bool] {.async.} =
  let hc = newAsyncHttpClient()
  