import asyncdispatch, httpclient, json

const
  baseUrl {.strdefine.} = "http://localhost/wordpress/wp-json/"
  apiToken {.strdefine.} = "xxx"

let
  accessHeader = newHttpHeaders {"api-token": apiToken}

# -------------------------------------------------------

proc getName*(ahc: AsyncHttpClient, phoneNumber: string): Future[string] {.async.} =
  return (await body await ahc.request(
    baseUrl & "wp_api_ext/getName/" & phoneNumber,
    HttpGet, "",
    accessHeader
  )).parsejson["display_name"].getStr
