import httpclient, json
import xmltree
import htmlparser, nimquery

type
  LoginFormData = tuple[csrf, captcha_ses, imgSrc: string]

const
  host = "https://rakhshan.com/"
  api = host & "wp-admin/admin-ajax.php"

let hc = newHttpClient()

proc getPage(): LoginFormData =
  let
    xml = parseHtml hc.getContent(host)
    el_csrf = xml.querySelector(".dig_nounce")
    el_ses = xml.querySelectorAll(".dig_captcha_ses")
    el_src = xml.querySelector(".dig_captcha")

  # echo ">>", el_ses.mapIt(it.attr "value").join("-")

  (
    el_csrf.attr "value",
    el_ses[1].attr "value",
    el_src.attr "src",
  )

proc loginData(number, csrf, code: string): MultipartData =
  result = newMultipartData()
  result["action"] = "digits_verifyotp_login"
  result["dtype"] = "1"
  result["digits"] = "1"
  result["rememberMe"] = "false"
  result["dig_ftoken"] = "-1"

  result["countrycode"] = "+98"
  result["mobileNo"] = number
  result["otp"] = code
  result["csrf"] = csrf


func genData(csrf, ses, number, capcha: string): MultipartData =
  result = newMultipartData()
  result["action"] = "digits_check_mob"
  result["login"] = "1"
  result["digits"] = "1"
  result["json"] = "1"
  result["username"] = ""
  result["email"] = ""
  result["dig_otp"] = ""
  result["digits_redirect_page"] = ""
  result["whatsapp"] = "0"
  result["output"] = "soap12"

  result["countrycode"] = "+98"
  # result["mobileNo"] = "9140026206"
  result["mobileNo"] = number
  result["mobmail"] = number

  result["captcha_ses"] = ses
  result["dig_captcha_ses"] = ses

  result["csrf"] = csrf
  result["dig_nounce"] = csrf

  result["captcha"] = capcha
  result["digits_reg_logincaptcha"] = capcha


let form = getPage()
writefile "play.png", hc.getContent form.imgSrc

echo "see play.png"

let req = hc.postContent(api, multipart = genData(
  form.csrf,
  form.captcha_ses,
  "9140026206",
  stdin.readline()))

echo pretty parseJson req
