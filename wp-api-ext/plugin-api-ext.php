<?php

/**
 * Plugin Name: wp API extension
 * Plugin URI: https://github.com/hamidb80/azmmonak/tree/main/wp-api-ext
 * Author: @hamidb80
 * Author URI: https://github.com/hamidb80
 * Version: 0.0.1
 * Description: a plugin to extend wordpress API designed for https://rakhshan.com/
 */


// init ----------------------------------------------------

define("WPS_FILE", __FILE__);
define("WPS_DIRECTORY", dirname(__FILE__));

// def ----------------------------------------------------

function WPAPIEXT_activate()
{
  add_option("api-token", "xxx");
}
function WPAPIEXT_deactivate()
{
  delete_option("api-token");
}
function WPAPIEXT_isApiTokenValid($api_token)
{
  return $api_token == get_option("api-token");
}

function runQuery($sql)
{
  global $wpdb;
  return $wpdb->get_results($sql);
}

function getUserLevel($userId)
{
  return intval(runQuery(
    "SELECT meta_value FROM wp_usermeta WHERE user_id=" . $userId . " AND meta_key='wp_user_level'"
  )[0]->meta_value);
}

function WPAPIEXT_getName(WP_REST_Request $req)
{
  // api token in the header
  if (!WPAPIEXT_isApiTokenValid($req->get_header("api-token")))
    return new WP_Error(401, 'Invalid api-token');

  $result = runQuery(
    "SELECT * FROM wp_users WHERE user_nicename = '" . $req->get_param("number") . "'"
  );

  if (empty($result))
    return new WP_Error(404, 'Not found');

  $user = (array)$result[0];
  $userLevel = getUserLevel($user["ID"]);
  $user["user_level"] = $userLevel;
  $user["is_admin"] = $userLevel > 2;
  return $user;
}

// register ----------------------------------------------------

register_activation_hook(__FILE__, 'WPAPIEXT_activate');
register_deactivation_hook(__FILE__, 'WPAPIEXT_deactivate');

// http://example.com/wp-json/myplugin/v1/author/(?P\d+).
add_action('rest_api_init', function () {
  register_rest_route('wp_api_ext', '/getName/(?P<number>[+\w]+)', array(
    'methods' => 'GET',
    'callback' => 'WPAPIEXT_getName',
  ));
});
