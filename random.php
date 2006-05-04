<?php
/*
 * random.php:
 * Acquire (strongly) random bytes from /dev/random.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: random.php,v 1.1 2006-05-04 11:58:32 chris Exp $
 * 
 */

/* random_bytes NUM
 * Return NUM bytes of random data. */
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

?>
