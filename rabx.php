<?php
/*
 * rabx.php:
 * RPC using Anything But XML.
 *
 * This is all a bit miserable, because PHP doesn't have string-streams (so
 * we have to do everything with substr) or exceptions (so we have to return
 * error objects and test for them).
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: rabx.php,v 1.18 2006-05-30 12:39:42 chris Exp $
 * 
 */

require_once('utility.php');

/*
 * Errors and error codes.
 */
define("RABX_ERROR_UNKNOWN", 0);
define("RABX_ERROR_INTERFACE", 1);
define("RABX_ERROR_TRANSPORT", 2);
define("RABX_ERROR_PROTOCOL", 3);

define("RABX_ERROR_MASK", 511); /* Mask off "error detected on server" bit */

define("RABX_ERROR_SERVER", 512);

define("RABX_ERROR_USER", 1024);

/* RABX_Error
 * Simple class to represent an error in RABX. */
class RABX_Error {
    var $code, $text, $extra;
    function RABX_Error($code, $text, $extra = null) {
        $this->code = $code;
        $this->text = $text;
        $this->extra = $extra;
    }
};

class RABX_Error_Unknown extends RABX_Error {};
class RABX_Error_Interface extends RABX_Error {};
class RABX_Error_Transport extends RABX_Error {};
class RABX_Error_Protocol extends RABX_Error {};
class RABX_Error_User extends RABX_Error {};

/* rabx_error CODE TEXT [EXTRA]
 * Return a suitable object representing the error with the given CODE,
 * descriptive TEXT, and optional EXTRA data. */
function rabx_error($code, $text, $extra = null) {
    if ($code >= RABX_ERROR_USER)
        return new RABX_Error_User($code, $text, $extra);
    $c = $code & RABX_ERROR_MASK;
    if ($c == RABX_ERROR_INTERFACE)
        return new RABX_Error_Interface($code, $text, $extra);
    else if ($c == RABX_ERROR_TRANSPORT)
        return new RABX_Error_Transport($code, $text, $extra);
    else if ($c == RABX_ERROR_PROTOCOL)
        return new RABX_Error_Protocol($code, $text, $extra);
    else
        return new RABX_Error_Unknown($code, $text, $extra);
}

/* rabx_is_error E
 * Does E represent an RABX error? */
function rabx_is_error($e) {
    if (is_object($e) and is_a($e, "RABX_Error"))
        return TRUE;
    else
        return FALSE;
}

/* 
 * Construction/parsing of wire format.
 */

/* rabx_netstring_wr STRING BUFFER
 * Append STRING to BUFFER, formatted as a netstring. Returns true on success
 * or an error on failure. */
function rabx_netstring_wr(&$string, &$buffer) {
    $l = setlocale(LC_NUMERIC, "0");
    setlocale(LC_NUMERIC, "C");
    $buffer .= sprintf("%d:%s,", strlen(&$string), &$string);
    setlocale(LC_NUMERIC, $l);
    return TRUE;
}

/* rabx_netstring_rd BUFFER POS
 * Read a netstring from BUFFER starting at position POS. Returns the string
 * read on success, or an error on failure. */
function rabx_netstring_rd(&$buffer, &$pos) {
    $avail = strlen(&$buffer) - $pos;
    if ($avail < 3)
        return rabx_error(RABX_ERROR_PROTOCOL, "not enough space for a netstring at position $pos");
    $m = array();
    if (!preg_match('/(\d+):/', &$buffer, &$m, 0, $pos))
        return rabx_error(RABX_ERROR_PROTOCOL, "bad netstring leader at position $pos");
    $len = $m[1];
    $pos += ($n = strlen($m[0]));
    $avail -= $n;

    if ($avail < $len + 1)
        return rabx_error(RABX_ERROR_PROTOCOL, "not enough space for netstring payload at position $pos");

    $res = substr(&$buffer, $pos, $len);
    $pos += $len;
    
    if (substr(&$buffer, $pos, 1) != ",")
        return rabx_error(RABX_ERROR_PROTOCOL, "no trailing \",\" after netstring at position $pos");

    ++$pos;
    --$avail;

    return $res;
}

/* rabx_wire_wr X BUFFER
 * Append the on-the-wire representation of X to BUFFER. Returns true on
 * success or an error on failure. */
function rabx_wire_wr(&$x, &$buffer) {
    if (is_object($x))
        return rabx_error(RABX_ERROR_INTERFACE, "can't pass objects over RABX");
    else if (is_array($x)) {
        /* Determine whether this is an associative array or vector. */
        $n = count($x);
        $f = 1;
        for ($i = 0; $i < $n; ++$i) {
            if (!array_key_exists($i, $x)) {
                $f = 0;
                break;
            }
        }
        if ($f) {
            /* "List" */
            $buffer .= 'L';
            $cnx = count($x);
            if (rabx_is_error($e = rabx_netstring_wr($cnx, $buffer)))
                return $e;
            for ($i = 0; $i < $n; ++$i) {
                if (rabx_is_error($e = rabx_wire_wr($x[$i], $buffer)))
                    return $e;
            }
            return TRUE;
        } else {
            /* "Associative array" */
            $buffer .= 'A';
            $cnx = count($x);
            if (rabx_is_error($e = rabx_netstring_wr($cnx, &$buffer)))
                return $e;
            foreach ($x as $k => $v) {
                if (rabx_is_error($e = rabx_wire_wr($k, &$buffer))
                    || rabx_is_error($e = rabx_wire_wr($v, &$buffer)))
                    return $e;
            }
            return TRUE;
        }
    } else {
        if (is_null($x)) {
            $buffer .= 'N';
            return TRUE;
        } else if (is_int($x) || is_bool($x))
            $buffer .= 'I';
        else if (is_float($x))
            $buffer .= 'R';
        else if (is_string($x))
            $buffer .= 'T';     /* XXX should check for UTF-8 */
        return rabx_netstring_wr($x, &$buffer);
    }
}

/* rabx_wire_rd BUFFER POS
 * Read the on-the-wire representation of some data from BUFFER beginning at
 * position POS. On error, returns an error. */
function rabx_wire_rd(&$buffer, &$pos) {
    if ($pos >= strlen(&$buffer))
        return rabx_error(RABX_ERROR_PROTOCOL, "attempt to read beyond end of buffer at position $pos");
    $type = substr(&$buffer, $pos, 1);
    ++$pos;

    /* Check for valid type. */
    if (!strchr("NIRTBLA", $type))
        return rabx_error(RABX_ERROR_PROTOCOL, "bad type character \"$type\" at position $pos");

    /* Null value. */
    if ($type == 'N')
        return null;
    
    /* All other types now encode a string, which is either the value or a
     * length. */
    if (rabx_is_error($x = rabx_netstring_rd(&$buffer, $pos)))
        return $x;

    if ($type == 'I') {
        if (!is_numeric($x))
            return rabx_error(RABX_ERROR_PROTOCOL, "integer value is not numeric at position $pos");
        return intval($x);
    } else if ($type == 'R') {
        if (!is_numeric($x))
            return rabx_error(RABX_ERROR_PROTOCOL, "real value is not numeric at position $pos");
        return floatval($x);
    } else if ($type == 'T') {  /* XXX UTF-8 */
        return $x;
    } else if ($type == 'B') { // Raw binary
        return $x;
    } else if ($type == 'L') {
        if (intval($x) != $x)
            return rabx_error(RABX_ERROR_PROTOCOL, "list length is not an integer at position $pos");
        $a = array();
        for ($i = 0; $i < intval($x); ++$i) {
            array_push($a, $e = rabx_wire_rd(&$buffer, $pos));
            if (rabx_is_error($e))
                return $e;
        }
        return $a;
    } else if ($type == 'A') {
        if (intval($x) != $x)
            return rabx_error(RABX_ERROR_PROTOCOL, "associative array length is not an integer at position $pos");
        $a = array();
        for ($i = 0; $i < intval($x); ++$i) {
            if (rabx_is_error($k = rabx_wire_rd(&$buffer, $pos)))
                return $k;
            if (rabx_is_error($v = rabx_wire_rd(&$buffer, $pos)))
                return $v;
            $a[$k] = $v;
        }
        return $a;
    } else
        /* NOTREACHED */
        return rabx_error(RABX_ERROR_UNKNOWN, "internal error at position $pos");
}

/* rabx_call_string FUNCTION ARGS
 * Return the on-the-wire data for a call to the named FUNCTION with the
 * given ARGS. */
function rabx_call_string($function, &$args) {
    $str = 'R';
    $ver = '0';
    rabx_netstring_wr($ver, &$str); /* 0 == version */
    rabx_netstring_wr($function, &$str); /* XXX errors */
    rabx_wire_wr($args, &$str);
    return $str;
}

/* rabx_return_string_parse STRING
 * Parse a function return out of STRING, returning corresponding PHP data
 * structures, or a RABX_Error on error. */
function rabx_return_string_parse (&$string) {
    $t = substr(&$string, 0, 1);
    if (strlen(&$string) < 1)
        return rabx_error(RABX_ERROR_PROTOCOL, "return string is too short");
    else if (!($t == 'S' || $t == 'E'))
        return rabx_error(RABX_ERROR_PROTOCOL, "first byte of return string should be \"S\" or \"E\", not \"$t\"");
    $off = 1;
    if (rabx_is_error($v = rabx_netstring_rd(&$string, $off)))
        return $v;
    else if ($v != 0)
        return rabx_error(RABX_ERROR_PROTOCOL, "unknown protocol version \"$ver\"");

    if ($t == "S")
        return rabx_wire_rd(&$string, $off);
    else {
        if (rabx_is_error($code = rabx_netstring_rd(&$string, $off)))
            return $code;
        else if (rabx_is_error($text = rabx_netstring_rd(&$string, $off)))
            return $text;
        $code = intval($code);
        $extra = null;
        if ($off < strlen(&$string)) {
            if (rabx_is_error($extra = rabx_wire_rd(&$string, $off)))
                return $extra;
        }
        return rabx_error($code, $text, $extra);
    }
}

/*
 * Implementation of client.
 */

function microtime_float()
{
    list($usec, $sec) = explode(" ", microtime());
    return ((float)$usec + (float)$sec);
}
 

class RABX_Client {
    var $ch, $url, $use_post = FALSE;
    var $lastt;

    /* constructor URL
     * Constructor; return a client that calls functions at the given URL. */
    function RABX_Client($url) {
        $this->url = $url;
        $this->ch = curl_init();
        curl_setopt($this->ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($this->ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
        curl_setopt($this->ch, CURLOPT_USERAGENT, 'PHP RABX client, version $Id: rabx.php,v 1.18 2006-05-30 12:39:42 chris Exp $');
        if (array_key_exists('http_proxy', $_SERVER))
            curl_setopt($this->ch, CURLOPT_PROXY, $_SERVER['http_proxy']);
        $use_post = FALSE;
    }

    /* call FUNCTION ARGUMENTS [FORCEPOST]
     * Call the named FUNCTION with the given ARGUMENTS (an array); if
     * FORCEPOST is true, use HTTP POST even if the request would be small
     * enough to fit in a GET. */
    function call($function, $args, $force_post = 0) {
        debug("RABX", "RABX calling $function via $this->url, arguments:", $args);

        $callstr = rabx_call_string($function, &$args);
        debug("RABXWIRE", "RABX raw send:", $callstr);
        if (rabx_is_error($callstr))
            return $callstr;

        $c = urlencode($callstr);
        $post = $this->use_post || $force_post;
        if (!$post and strlen($u = $this->url. "?$c") > 1024)
            $post = TRUE;

        if ($post) {
            curl_setopt($this->ch, CURLOPT_URL, $this->url);
            curl_setopt($this->ch, CURLOPT_POST, 1);
            curl_setopt($this->ch, CURLOPT_POSTFIELDS, $callstr);
        } else {
            curl_setopt($this->ch, CURLOPT_URL, $u);
            curl_setopt($this->ch, CURLOPT_HTTPGET, 1);
            /* By default curl passes a "Pragma: no-cache" header. Turn it
             * off. */
            curl_setopt($this->ch, CURLOPT_HTTPHEADER, array("Pragma: "));
        }

        if (!($r = curl_exec($this->ch)))
            return rabx_error(RABX_ERROR_TRANSPORT, curl_error($this->ch) . " calling $this->url");
        $C = curl_getinfo($this->ch, CURLINFO_HTTP_CODE);
        debug("RABXWIRE", "RABX raw result:", $r);

        if ($C != 200)
            return rabx_error(RABX_ERROR_TRANSPORT, "HTTP error $C calling $this->url");
        else {
            $result = rabx_return_string_parse($r);
            debug("RABX", "RABX result:", $result);
            return $result;
        }
    }
}

?>
