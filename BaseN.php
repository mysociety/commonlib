<?
/*
 * BaseN.php
 * A pseudo-base-N encoding (a generalisation of Adobe's ASCII85).
 * Enough of perllib/mySociety/BaseN.pm for now.
 *
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 * 
 * $Id: BaseN.php,v 1.2 2006-11-20 16:41:00 matthew Exp $
 *
 */

$std_alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
$std_alpha_key = array();
for ($i = 0; $i < strlen($std_alpha); ++$i) {
    $std_alpha_key[substr($std_alpha, $i, 1)] = $i;
}

# basen_blocksize N
# Return the block size for the pseudo-base-N encoding.
function basen_blocksize($n) {
    $blocksize = 0;
    $x = 0xffffffff;
    while ($x) {
        ++$blocksize;
        $x = floor($x / $n);
    }
    return $blocksize;
}

function basen_encodefast($n, $message) {
    global $std_alpha;
    if (!preg_match('/^[1-9]\d*$/', $n))
        die("N must be a positive integer");
    if (!isset($message))
        die("MESSAGE may not be undef");
    if ($n + 1 > strlen($std_alpha)) {
        die("not enough characters in standard alphabet");
    }

    # Each four-byte block of MESSAGE is encoded as $blocksize symbols in
    # base N. We encode a three-byte block as $blocksize - 1 symbols, two-byte
    # as $blocksize - 2, etc.
    $l = strlen($message);
    $blocksize = basen_blocksize($n);

    $res = '';
    for ($i = 0; $i < $l; $i += 4) {
        $nin = ($l - $i > 4) ? 4 : $l - $i;
        $nout = $blocksize;
        # PHP doesn't, would you believe it, have unsigned ints, and in fact
        # ignores unpack()ing with unsigned values. Genius.
        $val = (float)0;
        for ($j = 0; $j < $nin; ++$j) {
            $val *= 256; # Shifting forces a cast to integer. Genius again.
            $unpacked = unpack('Cc', substr($message, $i + $j, 1));
            $val += $unpacked['c'];
        }
        $nout -= (4 - $nin);

        $r = '';
        while ($val) {
            $rem = fmod($val, $n); # Of *course* % is integer only! Genius thrice.
            if ($rem<0) $rem += $n;
            $val = floor($val / $n);
            $r .= substr($std_alpha, $rem, 1);
        }

        # pad to block size.
        if (strlen($r) != $nout)
            $r .= str_repeat(substr($std_alpha, 0, 1), ($nout - strlen($r)));

        if (strlen($r) > $nout)
            die("internal error; length of output block exceeds nout = $nout");

        $res .= strrev($r);
    }

    return $res;
}

function basen_decodefast($n, $message) {
    global $std_alpha_key;
    if (!preg_match('/^[1-9]\d*$/', $n))
        die("N must be a positive integer");
    if (!isset($message))
        die("MESSAGE may not be undef");

    $blocksize = basen_blocksize($n);

    $res = '';
    $l = strlen($message);
    for ($i = 0; $i < $l; $i += $blocksize) {
        $nin = ($l - $i > $blocksize) ? $blocksize : $l - $i;
        $nout = 4;
        if ($nin < $blocksize) {
            $nout -= $blocksize - $nin;
            if ($nout < 0) return null;
        }

        $val = 0;
        for ($j = 0; $j < $nin; ++$j) {
            $val *= $n;
            $c = substr($message, $i + $j, 1);
            if (!array_key_exists($c, $std_alpha_key))
                return null;
            $val += $std_alpha_key[$c];
        }

        $r = pack('N', $val);
        if ($nout < 4) $r = substr($r, 4 - $nout, $nout);

        $res .= $r;
    }

    return $res;
}
