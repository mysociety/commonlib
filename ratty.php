<?php
/*
 * ratty.php:
 * Interface to rate-limiting.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: ratty.php,v 1.13 2005-01-11 10:49:10 chris Exp $
 * 
 */

require_once('error.php');
require_once('rabx.php');

$ratty_client = new RABX_Client(OPTION_RATTY_URL);

/* Force POST requests, as rate limiting is intrinsically
 * non-idempotent; it would be no use if cached. */
$ratty_client->use_post = TRUE;

function ratty_do_call($name, $args) {
    global $ratty_client;
    $res = $ratty_client->call("Ratty.$name", $args);
    if (rabx_is_error($res))
        err($res->text);
    else
        return $res;
}

/* ratty_test VALUES
 * Should this call to the page described in VALUES be permitted, on the basis
 * of a rate-limit? VALUES should include keys for any significant variables on
 * which rate-limiting should be applied, for instance postcodes or IDs of data
 * items which an attacker could scrape from the page. Returns NULL if the page
 * can be shown, STRING with user message if it should be, or an error code on
 * failure. Message can be an empty string if none was specified in the rule. */
function ratty_test($vals) {
    debug("RATTY", "Rate limiting", $vals);
    $res = ratty_do_call('test', array($vals));
    debug("RATTYRESULT", "Result is:", $res);
    return $res;
}

/* ratty_admin_available_fields
 * Returns all the fields ratty has seen as an array of pairs (field,
 * example) */
function ratty_admin_available_fields() {
    return ratty_do_call('admin_available_fields', array());
}

/* ratty_admin_update_rule
 * Updates a ratty rule. */
function ratty_admin_update_rule($vals, $conds) {
    return ratty_do_call('admin_update_rule', array($vals, $conds));
}

/* ratty_admin_delete_rule
 * Updates a ratty rule. */
function ratty_admin_delete_rule($id) {
    return ratty_do_call('admin_delete_rule', array($id));
}

/* ratty_admin_get_rules
 * Get info about all rules. */
function ratty_admin_get_rules() {
    return ratty_do_call('admin_get_rules', array($vals, $conds));
}

/* ratty_admin_get_rule
 * Get info about a rule. */
function ratty_admin_get_rule($id) {
    return ratty_do_call('admin_get_rule', array($id));
}


/* ratty_admin_get_conditions
 * Get all conditions for a rule. */
function ratty_admin_get_conditions($id) {
    return ratty_do_call('admin_get_conditions', array($id));
}


?>
