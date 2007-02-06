<?php
/*
 * random.php:
 * Acquire random bytes from /dev/random and /dev/urandom.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: random.php,v 1.2 2007-02-06 13:19:49 francis Exp $
 * 
 */

/* random_bytes NUM
 * Return NUM bytes of random data from /dev/random. */
function random_bytes($num) {
    global $random_bytes_filehandle;
    if ($num < 0)
        err("NUM must be nonnegative in random_bytes");
    if (!isset($random_bytes_filehandle)
        && !($random_bytes_filehandle = fopen("/dev/random", "r")))
            err("Unable to open /dev/random");
    $res = '';
    while (strlen($res) < $num)
        $res .= fread($random_bytes_filehandle, $num - strlen($res));
    return $res;
}

/* urandom_bytes NUM
 * Return NUM bytes of (partly pseudo) random data from /dev/urandom. */
function urandom_bytes($num) {
    global $urandom_bytes_filehandle;
    if ($num < 0)
        err("NUM must be nonnegative in urandom_bytes");
    if (!isset($urandom_bytes_filehandle)
        && !($urandom_bytes_filehandle = fopen("/dev/urandom", "r")))
            err("Unable to open /dev/urandom");
    $res = '';
    while (strlen($res) < $num)
        $res .= fread($urandom_bytes_filehandle, $num - strlen($res));
    return $res;
}

?>
