<?php
/*
 * ratty.php:
 * Interface to rate-limiting.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: ratty.php,v 1.15 2005-01-12 13:16:12 chris Exp $
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

/* ratty_test SCOPE VALUES
 * Should this call to the page described in VALUES be permitted, on the basis
 * of a rate-limit? VALUES should include keys for any significant variables on
 * which rate-limiting should be applied, for instance postcodes or IDs of data
 * items which an attacker could scrape from the page. Returns NULL if no rate
 * limit was tripped, or an array of (rule ID, explanatory message) if one was,
 * or an error code on failure. The message can be an empty string if none was
 * specified in the rule. */
function ratty_test($scope, $vals) {
    if (!isset($scope))
        err("SCOPE must be supplied");
    debug("RATTY", "Rate limiting", $vals);
    $res = ratty_do_call('test', array($scope, $vals));
    debug("RATTYRESULT", "Result is:", $res);
    return $res;
}

/* ratty_admin_available_fields SCOPE
 * Returns all the fields ratty has seen as an array of pairs of (field,
 * example). */
function ratty_admin_available_fields($scope) {
    return ratty_do_call('admin_available_fields', array($scope));
}

/* ratty_admin_update_rule
 * Updates a ratty rule. */
function ratty_admin_update_rule($scope, $vals, $conds) {
    return ratty_do_call('admin_update_rule', array($scope, $vals, $conds));
}

/* ratty_admin_delete_rule SCOPE ID
 * Updates a ratty rule. */
function ratty_admin_delete_rule($scope, $id) {
    return ratty_do_call('admin_delete_rule', array($scope, $id));
}

/* ratty_admin_get_rules SCOPE
 * Get info about all rules. */
function ratty_admin_get_rules($scope) {
    return ratty_do_call('admin_get_rules', array($scope));
}

/* ratty_admin_get_rule SCOPE ID
 * Get info about a rule. */
function ratty_admin_get_rule($scope, $id) {
    return ratty_do_call('admin_get_rule', array($scope, $id));
}

/* ratty_admin_get_conditions SCOPE ID
 * Get all conditions for a rule. */
function ratty_admin_get_conditions($scope, $id) {
    return ratty_do_call('admin_get_conditions', array($scope, $id));
}

?>
