<?php
/*
 * ratty.php:
 * Interface to rate-limiting.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: ratty.php,v 1.11 2004-11-22 12:22:39 francis Exp $
 * 
 */

// TODO: Write script to automatically generate this file from perldoc.

require_once('rabx.php');
require_once('template.php');

/* ratty_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function ratty_get_error($e) {
    if (!rabx_is_error($e))
        return FALSE;
    else
        return $e->text;
}

/* ratty_check_error R
 * If R indicates failure, displays error message and stops procesing.
 */
function ratty_check_error($data) {
    if ($error_message = ratty_get_error($data)) {
        template_show_error($error_message);
    }
}

$ratty_client = new RABX_Client(OPTION_RATTY_URL);

// Force POST requests, as rate limiting is intrinsically
// non-idempotent; it would be no use if cached
$ratty_client->use_post = TRUE;

/* ratty_test VALUES
 * Should this call to the page described in VALUES be permitted, on the basis
 * of a rate-limit? VALUES should include keys for any significant variables on
 * which rate-limiting should be applied, for instance postcodes or IDs of data
 * items which an attacker could scrape from the page. Returns NULL if
 * the page can be shown, STRING with user message if it should be, or an
 * error code on failure.  Message can be an empty string if none was 
 * specified in the rule. */
function ratty_test($vals) {
    global $ratty_client;
    debug("RATTY", "Rate limiting", $vals);
    $res = $ratty_client->call('Ratty.test', array($vals));
    ratty_check_error($res);
    debug("RATTYRESULT", "Result is:", $res);
    return $res;
}

/* ratty_admin_available_fields
 * Returns all the fields ratty has seen as an array of pairs (field,
 * example) */
function ratty_admin_available_fields() {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_available_fields', array());
    ratty_check_error($res);
    return $res;
}

/* ratty_admin_update_rule
 * Updates a ratty rule. */
function ratty_admin_update_rule($vals, $conds) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_update_rule', array($vals, $conds));
    ratty_check_error($res);
    return $res;
}

/* ratty_admin_delete_rule
 * Updates a ratty rule. */
function ratty_admin_delete_rule($id) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_delete_rule', array($id));
    ratty_check_error($res);
    return $res;
}


/* ratty_admin_get_rules
 * Get info about all rules. */
function ratty_admin_get_rules() {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_get_rules', array($vals, $conds));
    ratty_check_error($res);
    return $res;
}

/* ratty_admin_get_rule
 * Get info about a rule. */
function ratty_admin_get_rule($id) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_get_rule', array($id));
    ratty_check_error($res);
    return $res;
}


/* ratty_admin_get_conditions
 * Get all conditions for a rule. */
function ratty_admin_get_conditions($id) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_get_conditions', array($id));
    ratty_check_error($res);
    return $res;
}


?>
