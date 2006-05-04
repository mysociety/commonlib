<?php
/*
 * tracking.php:
 * Interface to our web tracking stuff.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: tracking.php,v 1.10 2006-05-04 12:14:13 chris Exp $
 * 
 */

require_once('urls.php');

/* track_code [EXTRA]
 * Return some HTML which will cause the page visit to be
 * recorded (by a browser suffering from the relevant privacy problem this
 * exploits). If specified, EXTRA should be a simple string which will be
 * recorded with the visit. */
function track_code($extra = null) {
    if (!OPTION_TRACKING)
        return '';
    $salt = sprintf('%08x', rand());
    $url = url_invoked();
    $sign = null;
    $img = null;
    if (is_null($extra)) {
        $sign = sha1(OPTION_TRACKING_SECRET . "\0$salt\0$url");
        $img = url_new(OPTION_TRACKING_URL, false,
                    "salt", $salt,
                    "url", $url,
                    "sign", $sign
                );
    } else {
        $sign = sha1(OPTION_TRACKING_SECRET . "\0$salt\0$url\0$extra");
        $img = url_new(OPTION_TRACKING_URL, false,
                    "salt", $salt,
                    "url", $url,
                    "extra", $extra,
                    "sign", $sign
                );
    }

    return '<!-- This "web bug" image is used to collect data which we use to improve our services. More on this at https://secure.mysociety.org/track/ --><img alt="" src="' . $img . '">';
}

/* track_event [EXTRA]
 * Like track_code, above, but actually output the HTML immediately. */
function track_event($extra = null) {
    print track_code($extra);
}

?>
