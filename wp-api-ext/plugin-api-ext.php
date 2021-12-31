<?php

/**
 * Plugin Name: wp API extension
 * Plugin URI: https://github.com/hamidb80/azmmonak/tree/main/wp-api-ext
 * Author: @hamidb80
 * Author URI: https://github.com/hamidb80
 * Version: 0.0.1
 * Description: a plugin for extend wordpress API designed for https://rakhshan.com/
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

function WPAPIEXT_getNameRoute(WP_REST_Request $req)
{
  global $wpdb;

  // api token in the header
  if (!WPAPIEXT_isApiTokenValid($req->get_header("api-token"))) 
    return new WP_Error(401, 'Invalid api-token');

  $result = $wpdb->get_results(
    "SELECT * FROM wp_users WHERE user_nicename = '" . $req->get_param("number") . "'"
  );

  if (empty($result))
    return new WP_Error(404, 'such user was not found');
  else
    return $result[0];
}

// register ----------------------------------------------------

register_activation_hook(__FILE__, 'WPAPIEXT_activate');
register_deactivation_hook(__FILE__, 'WPAPIEXT_deactivate');

// http://example.com/wp-json/myplugin/v1/author/(?P\d+).
add_action('rest_api_init', function () {
  register_rest_route('wp_api_ext', '/getName/(?P<number>[+\d]+)', array(
    'methods' => 'GET',
    'callback' => 'WPAPIEXT_getNameRoute',
  ));
});
