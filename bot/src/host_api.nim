import asyncdispatch, httpclient, json, strformat

const
  baseUrl = "https://rakhshan.com/wp-json/wp_api_ext"
  apiToken = "okm098QAZ" # getEnv("HOST_API_TOKEN")

let
  accessHeader = newHttpHeaders {"api-token": apiToken}

type UserApiModel* = object
  identifier*: string
  display_name*: string
  access_level*: int
  is_admin*: bool

# -------------------------------------------------------

func toUserApiModel(js: JsonNode): UserApiModel =
  UserApiModel(
    identifier: js["user_login"].getStr,
    display_name: js["display_name"].getStr,
    access_level: js["user_level"].getInt,
    is_admin: js["is_admin"].getBool
  )
  
proc getUserInfo*(identifier: string): Future[UserApiModel] {.async.} =
  let resp = await newAsyncHttpClient().request(
    fmt"{baseUrl}/getUser/{identifier}",
    HttpGet, "", accessHeader
  )

  if resp.code.is2xx:
    return (await resp.body).parseJson.toUserApiModel
  else:
    raise newException(ValueError, "failed")