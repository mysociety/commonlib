<?php
/*
 * conditional.php:
 * Support for HTTP conditional GET.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: conditional.php,v 1.1 2006-05-30 17:20:51 chris Exp $
 * 
 */

/* cond_parse_http_date DATE
 * Parse the supplied HTTP-style DATE, returning the number of seconds since
 * the epoch that it represents, or null if it could not be parsed. */
function cond_parse_http_date($date) {
    /* strptime uses week and month day names in the current locale, so need
     * to set it to 'C' and reset it on return. */
    $lc = setlocale(LC_TIME, "C");
    $r = null;
                                    /* RFC1123 */
    if (($d = strptime($date, '%a, %d %b %Y %H:%M:%S GMT'))
                                    /* RFC850 */
        || ($d = strptime($date, '%A, %d-%b-%y %H:%M:%S GMT'))
                                    /* asctime(3) */
        || ($d = strptime($date, '%a %b %e %H:%M:%S GMT')))
        $r = gmmktime($d);

    setlocale(LC_TIME, $lc);
    return $r;
}

/* cond_headers TIME [ETAG]
 * Send Last-Modified: and ETag: headers. The ETAG is assumed to be a weak
 * one. */
function cond_headers($time, $etag = null) {
    if (defined($time))
        header('Last-Modified: ' . gmstrftime('%a, %d %b %Y %H:%M:%S GMT', $time);
    if (defined($etag)) {
        header('ETag: W/"' . preg_replace('/[\\"]/', '\$1', $etag) . '"');
}

/* cond_304 TIME [ETAG]
 * Do a 304 Not Modified response. */
function cond_304($time, $etag = null) {
    header('Status: 304 Not Modified');
    cond_headers($time, $etag);
}

/* cond_maybe_respond TIME [ETAG]
 * If the client has indicated that they already have a page modified at or
 * after the given last-modified TIME, or one which matches the supplied ETAG,
 * then generate an appropriate 304 Not Modified response and return true;
 * otherwise, return false. Either TIME or ETAG may be null if a last-modified
 * time or entity tag are not available for this page. ETAG is assumed to be
 * a weak etag if it is supplied. */
function cond_maybe_respond($time, $etag = null) {

    if (!array_key_exists('REQUEST_METHOD', $_SERVER)
        && $_SERVER['REQUEST_METHOD'] != 'GET'
        && $_SERVER['REQUEST_METHOD'] != 'HEAD')
        return false;

    /* Look for an if-last-modified header */
    if (defined($time) && array_key_exists('HTTP_IF_MODIFIED_SINCE', $_SERVER)) {
        $t = cond_parse_http_date($_SERVER['HTTP_IF_MODIFIED_SINCE']);
        if (defined($t) && $t >= $time) {
            cond_304($time, $etag);
            return true;
        }
    }
    
    if (defined($etag) && array_key_exists('HTTP_IF_NONE_MATCH', $_SERVER)) {
        $etags = preg_split('/\s*,\s*/', $_SERVER['HTTP_IF_NONE_MATCH']);
        $q = 'W/"' . preg_replace('/[\\"]/', '\$1', $etag) . '"';
        foreach ($etags as $q2) {
            if ($q2 == $q) {
                cond_304($time, $etag);
                return true;
            }
        }
    }

    return false;
}


?>
