<?php
/*
 * utility.php:
 * General utility functions. Taken from the TheyWorkForYou.com source
 * code, and licensed under a BSD-style license.
 * 
 * Mainly: Copyright (c) 2003-2004, FaxYourMP Ltd 
 * Parts are: Copyright (c) 2004 UK Citizens Online Democracy
 *
 * $Id: utility.php,v 1.83 2007-10-01 15:55:02 francis Exp $
 * 
 */

/*
 * Magic quotes: these are a unique and unedifying feature of the whole PHP
 * trainwreck. Here we do our best to undo any damage we may have sustained,
 * at the small cost of inserting bowdlerised profanities into our code.
 */

/* unfck VAL
 * If VAL is a scalar, return the result of stripslashes(VAL) (i.e. with any
 * character preceded by a backslash replaced by that character). If VAL is an
 * array, return an array whose elements are the result of this function
 * applied to each element of that array. */
function unfck($v) {
    return is_array($v) ? array_map('unfck', $v) : stripslashes($v);
}

/* unfck_gpc
 * Apply the unfck function to elements of the global POST, GET, REQUEST and
 * COOKIE arrays, in place. */
function unfck_gpc() {
    foreach (array('POST', 'GET', 'REQUEST', 'COOKIE') as $gpc)
    $GLOBALS["_$gpc"] = array_map('unfck', $GLOBALS["_$gpc"]);
}

/* If magic_quotes_gpc is ON (in which case values in the global GET, POST and
 * COOKIE arrays will have been "escaped" by arbitrary insertion of
 * backslashes), try to undo this. */
if (get_magic_quotes_gpc()) unfck_gpc();

/* Make some vague effort to turn off the "magic quotes" nonsense. */
set_magic_quotes_runtime(0);

/*
 * Actually useful functions begin below here.
 */

/* XXX These functions used to be in utility.php, but have been separated so
 * that they can be called from TWFY (which has namespace clashes with the
 * functions in this file). So we include it here for compatibility. */
require_once('urls.php');
require_once('random.php');
require_once('debug.php');
require_once('validate.php');

/* canonicalise_postcode
 * Convert UK postcode to a unique form.  That is, remove all spaces and
 * capitalise it.  Then put back in a space in the right place.  */
function canonicalise_postcode($pc) {
    $pc = str_replace(' ', '', $pc);
    $pc = trim($pc);
    $pc = strtoupper($pc);
    $pc = preg_replace('#(\d[A-Z]{2})#', ' $1', $pc);
    return $pc;
}

/* canonicalise_partial_postcode
 * Convert UK postcode to display form of first part.  That is, remove all
 * spaces and capitalise it.  Then put back in a space in the right place.  */
function canonicalise_partial_postcode($pc) {
    $pc = str_replace(' ', '', $pc);
    $pc = trim($pc);
    $pc = strtoupper($pc);
    if (validate_postcode($pc)) {
        $pc = preg_replace('#(\d[A-Z]{2})#', '', $pc);
    } elseif (validate_partial_postcode($pc)) {
        # OK
    } else {
        err('Unexpected not full or partial postcode');
    }
    return $pc;
}

/* strip_tags_tospaces TEXT
 * Return a copy of TEXT in which certain block-level HTML tags have been
 * replaced by single spaces, and other HTML tags have been removed. */
function strip_tags_tospaces($text) {
    $text = preg_replace("#\<(p|br|div|td|tr|th|table)[^>]*\>#i", " ", $text);
    return strip_tags(trim($text)); 
}

/* trim_characters TEXT START LENGTH
 * Return a copy of TEXT with (optionally) chararacters stripped from the
 * beginning and/or end. HTML tags are first stripped from TEXT and/or replaced
 * with spaces per strip_tags_tospaces; then, if START is positive, whole words
 * are removed from the beginning of TEXT until at least START characters have
 * been removed. Any removed characters are replaced with "...". If the length
 * of the resulting string exceeds LENGTH, then whole words are removed from
 * the end of TEXT until its total length is smaller than LENGTH, including an
 * ellipsis ("...") which is appended to the end. Long words (i.e. runs of
 * nonspace characters) have spaces inserted in them for neater
 * line-wrapping. */
function trim_characters ($text, $start, $length) {
    $text = strip_tags_tospaces($text);

    // Split long strings up so they don't go too long.
    // Mainly for URLs which are displayed, but aren't links when trimmed.
    # http://bugs.php.net/bug.php?id=42298 for why I'm having to repeat
    # \S 60 times...
    $text = rtrim(preg_replace('/' . str_repeat('\S', 60) . '/u', '$0 ', $text));

    // Otherwise the word boundary matching goes odd...
    $text = preg_replace("/[\n\r]/", " ", $text);

    // Trim start.
    if ($start > 0) {
        $text = substr($text, $start);

        // Word boundary.         
        if (preg_match ("/.+?\b(.*)/", $text, $matches)) {
            $text = $matches[1];
            // Strip spare space at the start.
            $text = ltrim($text);
        }
        $text = '...' . $text;
    }

    // Trim end.
    if (mb_strlen($text) > $length) {

        // Allow space for ellipsis.
        $text = mb_substr($text, 0, $length - 3, 'utf-8'); 

        // Word boundary.         
        if (preg_match ("/(.*)\b.+/u", $text, $matches)) {
            $text = $matches[1];
            // Strip spare space at the end.
            $text = rtrim($text);
        }
        // We don't want to use the HTML entity for an ellipsis (&#8230;), because then 
        // it screws up when we subsequently use htmlentities() to print the returned
        // string!
        $text .= '...'; 
    }

    return $text;
}

/* XXX should these two go in urls.php? */

/* trim_url URL
 * Returns the URL formatted as a link to itself.  The displayed
 * text is shortened to just the first part of the URL. */
function trim_url($url) {
    $short_url = $url;
    $url_bits = parse_url($url);
    if (array_key_exists('path', $url_bits) && array_key_exists('scheme', $url_bits) && array_key_exists('host', $url_bits))
        if ($url != "" && ($url_bits['path'] != '/' || array_key_exists('query', $url_bits)) )
            $short_url = $url_bits['scheme'] . "://" .  $url_bits['host'] . "/...";
    return "<a href=\"" .  htmlspecialchars($url) .  "\">" .  htmlspecialchars($short_url) . "</a>";
}

/* trim_url_to_domain URL
 * Returns the domain formatted as a link to the URL. */
function trim_url_to_domain($url) {
    $short_url = $url;
    $url_bits = parse_url($url);
    if (array_key_exists('path', $url_bits) && array_key_exists('scheme', $url_bits) && array_key_exists('host', $url_bits))
        $short_url = $url_bits['host'];
    $short_url = str_replace("www.", "", $short_url);
    return "<a href=\"" .  htmlspecialchars($url) .  "\">" .  htmlspecialchars($short_url) . "</a>";
}


/* convert_to_unix_newlines TEXT
 * Return a copy of TEXT in which all DOS/RFC822-style line-endings (CRLF,
 * "\r\n") have been converted to UNIX-style line-endings (LF, "\n"). */
function convert_to_unix_newlines($text) {
    $text = preg_replace("/(\r\n|\n|\r)/s", "\n", $text);
    return $text;
}

/* get_http_var NAME [DEFAULTorALLOW]
 * Return the value of the GET or POST parameter with the given NAME; or, if no
 * such parameter is present, DEFAULT; or, if DEFAULT is not specified or is a
 * boolean, the empty string ("").
 * If DEFAULT is a boolean, allow the input to be changed (currently, only
 * for Esperanto input to take .x to various accented characters). It's thus
 * currently impossible to have a default and have changed input, but nowhere
 * on the PledgeBank site requires a default anyway.
 */
function get_http_var($name, $default='') {
    global $lang;

    if (is_bool($default)) {
        $allow_changes = true;
        $default = '';
    } else {
        $allow_changes = false;
    }

    if (array_key_exists($name, $_GET)) {
        $var = $_GET[$name];
        if (!is_array($var)) $var = trim($var);
    } elseif (array_key_exists($name, $_POST)) {
        $var = $_POST[$name];
        if (!is_array($var)) $var = trim($var);
    } else { 
        $var = $default;
    }
    if ($allow_changes && $lang == 'eo')
        $var = input_esperanto($var);
    $var = str_replace("\r", '', $var);
    return $var;
}

$eo_search = array('/C[Xx]/', '/c[Xx]/',
                   '/G[Xx]/', '/g[Xx]/',
                   '/H[Xx]/', '/h[Xx]/',
                   '/J[Xx]/', '/j[Xx]/',
                   '/S[Xx]/', '/s[Xx]/',
                   '/U[Xx]/', '/u[Xx]/');
$eo_replace = array("\xc4\x88", "\xc4\x89",
                    "\xc4\x9c", "\xc4\x9d",
                    "\xc4\xa4", "\xc4\xa5",
                    "\xc4\xb4", "\xc4\xb5",
                    "\xc5\x9c", "\xc5\x9d",
                    "\xc5\xac", "\xc5\xad");
$eo_replace2 = array_map(create_function('$a', 'return substr($a, 1, 1)."x";'), $eo_search);
$eo_search2 = array_map(create_function('$a', 'return "/$a/";'), $eo_replace);
function input_esperanto($text) {
    global $eo_search, $eo_replace, $eo_search2, $eo_replace2;
    $text = preg_replace($eo_search, $eo_replace, $text);
    $search = array("#https?://[^\s<>{}()]+[^\s.,<>{}()]#ie", 
                    "#\swww\.[a-z0-9\-]+(?:\.[a-z0-9\-\~]+)+(?:/[^ <>{}()\n\r]*[^., <>{}()\n\r])?#ie",
                    "#\s[a-z0-9\-_.]+@[^,< \n\r]*[^.,< \n\r]#ie");
    $text = preg_replace($search, 'preg_replace($eo_search2, $eo_replace2, "$0");', " $text ");
    $text = trim($text);
    return $text;
}

/* make_plural NUMBER SINGULAR PLURAL
 * If NUMBER is 1, return SINGULAR; if NUMBER is not 1, return PLURAL
 * if it's there, otherwise WORD catenated with "s". */
function make_plural($number, $singular, $plural='') {
	if ($number == 1)
		return $singular;
	if ($plural)
		return $plural;
	return $singular . 's';
}

/* javascript_focus_set FORM ELEMENT
 * Return a bit of JavaScript which will set the user's input focus to the
 * input element of the given FORM (id) and ELEMENT (name). */
function javascript_focus_set($form, $elt) {
    return "document.$form.$elt.focus();";
}

/* check_is_valid_regexp STRING
 * Return true if STRING is (approximately) a valid Perl5 regular
 * expression. */
function check_is_valid_regexp($regex) {
    $result = preg_match("/" . str_replace("/", "\/", $regex) .  "/", "");
    return ($result !== FALSE);
}

/* http_auth_user
 * Return the user name authenticated by HTTP, or *unknown* if none.
 * XXX should this not return null? */
function http_auth_user() {
    $editor = null;
    if (array_key_exists("REMOTE_USER", $_SERVER))
        $editor = $_SERVER["REMOTE_USER"];
    if (!$editor) 
        $editor = "*unknown*";
    return $editor;
}

/* add_tooltip TEXT TIP
 * Return an HTML <span>...</span> containing TEXT with TIP passed as the title
 * attribute of the span, so that it appears as a tooltip in common graphical
 * browsers. */
function add_tooltip($text, $tip) {
    return "<span title=\"" . htmlspecialchars($tip) . "\">$text</span>";
}

/* merge_spaces TEXT
 * Converts all consecutive spaces, including newlines, into one space each. */
function merge_spaces($text) {
    $text = preg_replace("/\s+/s", " ", $text);
    return $text;
}

/* ms_make_clickable TEXT NOFOLLOW
 * Returns TEXT with obvious links made into HTML hrefs.  Set
 * NOFOLLOW to true to add rel='nofollow' to the links. */
// Taken from WordPress, tweaked slightly to work with , and . at end of some URLs.
function ms_make_clickable($ret, $params = array()) {
    $nofollow = array_key_exists('nofollow', $params) && $params['nofollow']==true;
    $contract = array_key_exists('contract', $params) && $params['contract']==true;
    $ret = ' ' . $ret . ' ';
    $ret = preg_replace("#(https?)://([^\s<>{}()]+[^\s.,<>{}()])#i", "<a href='$1://$2'" . 
                ($nofollow ? " rel='nofollow'" : ""). ">$1://$2</a>", $ret);
    $ret = preg_replace("#(\s)www\.([a-z0-9\-]+)((?:\.[a-z0-9\-\~]+)+)((?:/[^ <>{}()\n\r]*[^., <>{}()\n\r])?)#i", 
                "$1<a href='http://www.$2$3$4'" . ($nofollow ? " rel='nofollow'" : "") . ">www.$2$3$4</a>", $ret);
    if ($contract)
        $ret = preg_replace("#(<a href='[^']*'(?: rel='nofollow')?>)([^<]{40})[^<]{3,}</a>#", '$1$2...</a>', $ret);
    $ret = preg_replace("#(\s)([a-z0-9\-_.]+)@([^,< \n\r]*[^.,< \n\r])#i", "$1<a href=\"mailto:$2@$3\">$2@$3</a>", $ret);
    $ret = trim($ret);
    return $ret;
}

function ordinal($cardinal) {
    global $locale_current;
    switch ($locale_current) {
        case 'eo': return $cardinal . '-a';
        case 'nl': return $cardinal . 'e';
        default: return english_ordinal($cardinal);
    }
}

# Converts an ordinal number 1, 2, 3... into a cardinal 1st, 2nd, 3rd...
# Taken from make_ranking in TWFY codebase.
function english_ordinal($cardinal)
{
    # 11th, 12th, 13th use "th" not "st", "nd", "rd"
    if (floor(($cardinal % 100) / 10) == 1)
        return $cardinal . "th";
    # 1st
    if ($cardinal % 10 == 1)
        return $cardinal . "st";
    # 2nd
    if ($cardinal % 10 == 2)
        return $cardinal . "nd";
    # 3rd
    if ($cardinal % 10 == 3)
        return $cardinal . "rd";
    # Everything else use th
    return $cardinal . "th";
}

/* prettify THING [HTML]
   Returns a nicer form of THING for things that it knows about, otherwise just returns the string.
 */
function prettify($s, $html = true) {
    global $locale_current;

    if (preg_match('#^(\d{4})-(\d\d)-(\d\d)$#',$s,$m)) {
        list(,$y,$m,$d) = $m;
        $e = mktime(12,0,0,$m,$d,$y);
        if ($locale_current == 'en-gb') {
            if ($html)
                return date('j<\sup>S</\sup> F Y', $e);
            return date('jS F Y', $e);
        } elseif ($locale_current == 'eo')
            return strftime('la %e-a de %B %Y', $e);
	elseif ($locale_current == 'zh')
            return strftime('%Y&#24180;%m&#26376;%d&#26085;', $e);
        return strftime('%e %B %Y', $e);
    }
    if (preg_match('#^(\d{4})-(\d\d)-(\d\d) (\d\d:\d\d:\d\d)$#',$s,$m)) {
        list(,$y,$m,$d,$tim) = $m;
        $e = mktime(12,0,0,$m,$d,$y);
        if ($locale_current == 'en-gb') {
            if ($html)
                return date('j<\sup>S</\sup> F Y', $e);
            return date('jS F Y', $e);
        }
        return strftime('%e %B %Y', $e)." $tim";
    }
    if ($s>100000000) {
        # Assume it's an epoch
        if ($locale_current == 'zh') {
            $tt = strftime('%H:%M', $s);
            $t = time();
            if (strftime('%Y%m%d', $s) == strftime('%Y%m%d', $t))
                $tt = "$tt " . _('today');
            else
                $tt = "$tt, " . strftime('%Y&#24180;%m&#26376;%d&#26085;', $s);
            return $tt;
	}
        $tt = strftime('%H:%M', $s);
        $t = time();
        if (strftime('%Y%m%d', $s) == strftime('%Y%m%d', $t))
            $tt = "$tt " . _('today');
        elseif (strftime('%U %Y', $s) == strftime('%U %Y', $t))
            $tt = "$tt, " . strftime('%A', $s);
        elseif (strftime('%Y', $s) == strftime('%Y', $t))
            $tt = "$tt, " . strftime('%A %e %B', $s);
        else
            $tt = "$tt, " . strftime('%a %e %B %Y', $s);
        return $tt;
    }
    if (ctype_digit($s))
        return prettify_num($s);
    return $s;
}
function prettify_num($s) {
    if (ctype_digit($s)) {
        $locale_info = localeconv();
        return number_format($s, 0, $locale_info['decimal_point'], $locale_info['thousands_sep']);
    }
    return $s;
}

function spoonerise($s) {
    return preg_replace('#^(.)(.*? )(.)#', '$3$2$1', $s);
}

# Convert a user-entered string into an array of Web 2.0 compatible "tags" (or
# "keywords", as they used to be called)
# XXX function not properly complete, maybe. I'm keeping all punctuation except
# for commas which are turned into space separators. There is no flickr-like
# double quoting - but then, delicious doesn't do that at all. Blimey, it's
# almost like there is no RFC for this!
function make_web20_tags($tags) {
    $tags = strtolower($tags); 
    $tags = preg_replace('/,/',' ', $tags);
    $tags = preg_replace('/\s+/',' ', $tags);
    $tags = trim($tags);
    $tag_array = split(" ", $tags);
    return $tag_array;
}

/*

// some tests of the above

define('OPTION_PHP_DEBUG_LEVEL', 4);
print "debug(...)\n";
debug('header', 'text');
debug('header', 'text', array(1, 2, 3));
print "done\n";

print "vardump(...)\n";
vardump(array(1, 2, 3));
print "done\n";

foreach (array('chris', 'chris@ex-parrot.com', 'chris@[127.0.0.1]', 'fish soup @octopus', 'chris@_.com') as $a) {
    print "$a -> " . (validate_email($a) ? 'VALID' : 'NOT VALID') . "\n";
}

foreach (array('CB4 1EP', 'fish soup') as $pc) {
    print "validate_postcode('$pc') = " . validate_postcode($pc) . "\n";
}

print "getmicrotime() = " . getmicrotime() . "\n";

$text = 'I returned and saw under the sun, that the race is not to the swift, nor the battle to the strong, neither yet bread to the wise, nor yet riches to men of understanding, nor yet favour to men of skill; but time and chance happeneth to them all.';

print "\$text = '$text'\n";
print "trim_characters(\$text, 50, 999) = '" . trim_characters($text, 15, 999) . "'\n";
print "trim_characters(\$text, 0, 50) = '" . trim_characters($text, 0, 50) . "'\n";

$text = "fish\r\nsoup";
print "\$text = '$text'\n";
print "convert_to_unix_newlines(\$text) = '" . convert_to_unix_newlines($text) . "'\n";

// hard to test get_http_var in this environment

print "make_plural(1, 'fish', 'fishes') = '" . make_plural(1, 'fish', 'fishes') . "'\n";
print "make_plural(-1, 'fish', 'fishes') = '" . make_plural(-1, 'fish', 'fishes') . "'\n";

print "debug_timestamp():";
debug_timestamp();
sleep(1);
debug_timestamp();

print "invoked_url() = '" . invoked_url() . "'\n";

foreach (array('\w*\s*\w*', 'fish soup', '**') as $re) {
    print "check_is_valid_regexp('$re') = " . check_is_valid_regexp($re) . "\n";
}

print "url_new('http://www.microsoft.com', 0, 'fish', 'soup') = '" . url_new('http://www.microsoft.com', 0, 'fish', 'soup')  . "'\n";

print "http_auth_user() = '" . http_auth_user() . "'\n";

print "add_tooltip('fish', '\"soup\"') = '" . add_tooltip('fish', '"soup"') . "'\n";

*/

?>
