<?php
/*
 * ratty.php:
 * Interface to rate-limiting.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: ratty.php,v 1.7 2004-11-12 10:02:33 francis Exp $
 * 
 */

// TODO: Write script to automatically generate this file from perldoc.

require_once('rabx.php');

/* ratty_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function ratty_get_error($e) {
    if (!rabx_is_error($e))
        return FALSE;
    else
        return $e->text;
}

$ratty_client = new RABX_Client(OPTION_RATTY_URL);

// Force POST requests, as rate limiting is intrinsically
// non-idempotent; it would be no use if cached
$ratty_client->use_post = TRUE;

/* ratty_test VALUES
 * Should this call to the page described in VALUES be permitted, on the basis
 * of a rate-limit? VALUES should include keys for any significant variables on
 * which rate-limiting should be applied, for instance postcodes or IDs of data
 * items which an attacker could scrape from the page. Returns TRUE if the page
 * can be shown, FALSE if it should not, or an error code on failure. */
function ratty_test($vals) {
    global $ratty_client;
    debug("RATTY", "Rate limiting", $vals);
    $res = $ratty_client->call('Ratty.test', array($vals));
    if ($fyr_error_message = ratty_get_error($res)) {
        include "../templates/generalerror.html";
        exit;
    }
    debug("RATTYRESULT", "Result is:", $res);
    return $res != 0;
}

/* ratty_admin_available_fields
 * Returns all the fields ratty has seen as an array of pairs (field,
 * example) */
function ratty_admin_available_fields() {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_available_fields', array());
    if ($fyr_error_message = ratty_get_error($res)) {
        include "../templates/generalerror.html";
        exit;
    }
    return $res;
}

/* ratty_admin_update_rule
 * Updates a ratty rule. */
function ratty_admin_update_rule($vals, $conds) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_update_rule', array($vals, $conds));
    if ($fyr_error_message = ratty_get_error($res)) {
        include "../templates/generalerror.html";
        exit;
    }
    return $res;
}

/* ratty_admin_get_rules
 * Get info about all rules. */
function ratty_admin_get_rules() {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_get_rules', array($vals, $conds));
    if ($fyr_error_message = ratty_get_error($res)) {
        include "../templates/generalerror.html";
        exit;
    }
    return $res;
}

/* ratty_admin_get_rule
 * Get info about a rule. */
function ratty_admin_get_rule($id) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_get_rule', array($id));
    if ($fyr_error_message = ratty_get_error($res)) {
        include "../templates/generalerror.html";
        exit;
    }
    return $res;
}


/* ratty_admin_get_conditions
 * Get all conditions for a rule. */
function ratty_admin_get_conditions($id) {
    global $ratty_client;
    $res = $ratty_client->call('Ratty.admin_get_conditions', array($id));
    if ($fyr_error_message = ratty_get_error($res)) {
        include "../templates/generalerror.html";
        exit;
    }
    return $res;
}


?>
