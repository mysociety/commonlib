<?php
/*
 * ratty.php:
 * Interface to rate-limiting.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: ratty.php,v 1.3 2004-10-29 10:24:02 chris Exp $
 * 
 */

require_once('rabx.php');

$ratty_client = new RABX_Client(OPTION_RATTY_URL);
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
    return $res != 0;
}

?>
