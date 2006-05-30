<?php
/*
 * conditional.php:
 * Support for HTTP conditional GET.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: conditional.php,v 1.4 2006-05-30 20:59:40 chris Exp $
 * 
 */

$cond_wkday_re = '(Sun|Mon|Tue|Wed|Thu|Fri|Sat)';
$cond_weekday_re = '(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday)';
$cond_month_re = '(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)';
$cond_month_map = array(
        'Jan' =>  1, 'Feb' =>  2, 'Mar' =>  3, 'Apr' =>  4,
        'May' =>  5, 'Jun' =>  6, 'Jul' =>  7, 'Aug' =>  8,
        'Sep' =>  9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12
    );

$cond_date1_re = '(\d\d) ' . $cond_month_re . ' (\d\d\d\d)';
$cond_date2_re = '(\d\d)-' . $cond_month_re . '-(\d\d)';
$cond_date3_re = $cond_month_re . ' (\d\d| \d)';

$cond_time_re = '([01][0-9]|2[0-3]):([0-5][0-9]):([0-5][0-9]|6[012])';
    /* XXX RFC 2616 prohibits seconds beyond 59, but presumably they will occur
     * as leap seconds sometimes. */

/* cond_parse_http_date DATE
 * Parse the supplied HTTP-style DATE, returning the number of seconds since
 * the epoch that it represents, or null if it could not be parsed. */
function cond_parse_http_date($date) {
    /* Unfortunately there is no strptime in PHP <5, so we must do this
     * manually. */
    $H = $M = $S = 0;
    $Y = $m = $d = 0;

    $ma = array();
    global $cond_wkday_re, $cond_weekday_re, $cond_month_re, $cond_month_map,
            $cond_date1_re, $cond_date2_re, $cond_date3_re, $cond_time_re;
    if (preg_match("/^$cond_wkday_re, $cond_date1_re $cond_time_re GMT\$/", $date, $ma)) {
        /* RFC 1123 */
        $d = $ma[2];
        $m = $cond_month_map[$ma[3]];
        $Y = $ma[4];
        $H = $ma[5];
        $M = $ma[6];
        $S = $ma[7];
    } else if (preg_match("/^$cond_weekday_re, $cond_date2_re $cond_time_re GMT\$/", $date, $ma)) {
        /* RFC 850 */
        $d = $ma[2];
        $m = $cond_month_map[$ma[3]];
        $Y = $ma[4] + ($ma[4] < 50 ? 2000 : 1900); /* XXX */
        $H = $ma[5];
        $M = $ma[6];
        $S = $ma[7];
    } else if (preg_match("/^$cond_wkday_re $cond_date3_re $cond_time_re (\\d{4})\$/", $date, $ma)) {
        /* asctime(3) */
        $d = preg_replace('/ /', '', $ma[3]);
        $m = $cond_month_map[$ma[2]];
        $Y = $ma[7];
        $H = $ma[4];
        $M = $ma[5];
        $S = $ma[6];
    } else
        return null;

    return gmmktime($H, $M, $S, $m, $d, $Y);
}

/* cond_headers TIME [ETAG]
 * Send Last-Modified: and ETag: headers. The ETAG is assumed to be a weak
 * one. */
function cond_headers($time, $etag = null) {
    if (isset($time))
        header('Last-Modified: ' . gmstrftime('%a, %d %b %Y %H:%M:%S GMT', $time));
    if (isset($etag)) {
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
    if (isset($time) && array_key_exists('HTTP_IF_MODIFIED_SINCE', $_SERVER)) {
        $t = cond_parse_http_date($_SERVER['HTTP_IF_MODIFIED_SINCE']);
        if (isset($t) && $t >= $time) {
            cond_304($time, $etag);
            return true;
        }
    }
    
    if (isset($etag) && array_key_exists('HTTP_IF_NONE_MATCH', $_SERVER)) {
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
