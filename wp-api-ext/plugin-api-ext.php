<?php

/**
 * Plugin Name: wp API extension
 * Plugin URI: https://github.com/hamidb80/azmmonak/tree/main/wp-api-ext
 * Author: @hamidb80
 * Author URI: https://github.com/hamidb80
 * Version: 0.0.2
 * Description: a plugin to extend wordpress API designed for https://rakhshan.com/
 */


// init ----------------------------------------------------

define("WPS_FILE", __FILE__);
define("WPS_DIRECTORY", dirname(__FILE__));

// def ----------------------------------------------------

# ------ hooks -------
function WPAPIEXT_activate()
{
  # api token will be stored here as "WPAPIEXT_API_TOKEN"
  add_option("WPAPIEXT_settings"); 
}
function WPAPIEXT_deactivate()
{
  delete_option("WPAPIEXT_settings");
}

// ------ utils -------
function WPAPIEXT_isApiTokenValid($api_token)
{
  return $api_token == get_option("WPAPIEXT_settings")["WPAPIEXT_API_TOKEN"];
}

function runQuery($sql)
{
  global $wpdb;
  return $wpdb->get_results($sql);
}

# ------ impl -------

// >>> get user info

function getUserLevel($userId)
{
  return intval(runQuery(
    "SELECT meta_value FROM wp_usermeta WHERE user_id=" . $userId . " AND meta_key='wp_user_level'"
  )[0]->meta_value);
}

function WPAPIEXT_getUser(WP_REST_Request $req)
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

// >>> setting page
// generated using: http://wpsettingsapi.jeroensormani.com/

function WPAPIEXT_add_admin_menu()
{
  add_menu_page('wp-api-ext', 'wp-api-ext', 'manage_options', 'wp-api-ext', 'WPAPIEXT_options_page');
}

function WPAPIEXT_settings_init()
{
  register_setting('pluginPage', 'WPAPIEXT_settings');

  add_settings_section(
    'WPAPIEXT_pluginPage_section',
    __('Your section description', 'set token api'),
    'WPAPIEXT_settings_section_callback',
    'pluginPage'
  );

  add_settings_field(
    'WPAPIEXT_API_TOKEN',
    __('Settings field description', 'set token api'),
    'WPAPIEXT_API_TOKEN_render',
    'pluginPage',
    'WPAPIEXT_pluginPage_section'
  );
}

function WPAPIEXT_API_TOKEN_render()
{
  $options = get_option('WPAPIEXT_settings');
?>
  <input type='text' name='WPAPIEXT_settings[WPAPIEXT_API_TOKEN]' value='<?php echo $options['WPAPIEXT_API_TOKEN']; ?>'>
<?php
}

function WPAPIEXT_settings_section_callback()
{
  echo __('This section description', 'set token api');
}

function WPAPIEXT_options_page()
{
?>
  <form action='options.php' method='post'>
    <h2>wp-api-ext</h2>
    <?php
    settings_fields('pluginPage');
    do_settings_sections('pluginPage');
    submit_button();
    ?>
  </form>
<?php
}

// register ----------------------------------------------------

register_activation_hook(__FILE__, 'WPAPIEXT_activate');
register_deactivation_hook(__FILE__, 'WPAPIEXT_deactivate');

add_action('admin_menu', 'WPAPIEXT_add_admin_menu');
add_action('admin_init', 'WPAPIEXT_settings_init');

// http://example.com/wp-json/myplugin/v1/author/(?P\d+).
add_action('rest_api_init', function () {
  register_rest_route('wp_api_ext', '/getUser/(?P<number>[+\w]+)', array(
    'methods' => 'GET',
    'callback' => 'WPAPIEXT_getUser',
  ));
});
