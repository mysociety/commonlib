<?php
/*
 * ratty.php:
 * Interface to rate-limiting.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: ratty.php,v 1.5 2004-11-08 18:27:17 francis Exp $
 * 
 */

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

?>
