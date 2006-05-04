<?php
/*
 * utility.php:
 * General utility functions. Taken from the TheyWorkForYou.com source
 * code, and licensed under a BSD-style license.
 * 
 * Mainly: Copyright (c) 2003-2004, FaxYourMP Ltd 
 * Parts are: Copyright (c) 2004 UK Citizens Online Democracy
 *
 * $Id: utility.php,v 1.70 2006-05-04 11:58:32 chris Exp $
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

/* debug HEADER TEXT [VARIABLE]
 * Print, to the page, a debugging variable, if a debug=... parameter is
 * present. The message is prefixed with the HEADER and consists of the passed
 * TEXT and an optional (perhaps array or class) VARIABLE which, if present, is
 * also dumped to the page. Display of items is dependent on the integer value
 * of the debug query variable and the passed HEADER, according to the table in
 * $levels below. */
function debug ($header, $text="", $complex_variable=null) {

	// We set ?debug=n in the URL.
	// n is a number from (currently) 1 to 4.
	// This sets what amount of debug information is shown.
	// For level '1' we show anything that is passed to this function
	// with a $header in $levels[1].
	// For level '2', anything with a $header in $levels[1] AND $levels[2].
	// Level '4' shows everything.
    // $complex_variable is dumped in full, so you can put arrays/hashes here
	
	//$debug_level = get_http_var("debug");  // disabled - information revealing security hole

    $debug_level = OPTION_PHP_DEBUG_LEVEL;
	
	if ($debug_level != '') {
	
		// Set which level shows which types of debug info.
		$levels = array (
			1 => array ('FRONTEND', 'WARNING', 'MAPIT', 'DADEM', 'QUEUE', 'TIMESTAMP'),
			2 => array ('MAPITRESULT', 'DADEMRESULT', 'RATTY'), 
			3 => array ('XMLRPC', 'RABX', 'RATTYRESULT'),
			4 => array ('RABXWIRE', 'SERIALIZE'),
		);
	
		// Store which headers we are allowed to show.
		$allowed_headers = array();
		
		if ($debug_level > count($levels)) {
			$max_level_to_show = count($levels);
		} else {
			$max_level_to_show = $debug_level;
		}
		
		for ($n = 1; $n <= $max_level_to_show; $n++) {
			$allowed_headers = array_merge ($allowed_headers, $levels[$n] );
		}
		
		// If we can show this header, then, er, show it.
		if ( in_array($header, $allowed_headers) || $debug_level >= 4) {
            	
			print "<p><span style=\"color:#039;\"><strong>$header</strong></span> $text";
            if (isset($complex_variable)) {
                print "</p><p>";
                vardump($complex_variable);
            }
            print "</p>\n";	
		}
	}
}


/* vardump VARIABLE
 * Dump VARIABLE to the page, properly escaped and wrapped in <pre> tags. */
function vardump($blah) {
    /* Miserable. We need to encode entities in the output, which means messing
     * about with output buffering. */
    ob_start();
    var_dump($blah);
    $d = ob_get_contents();
    ob_end_clean();
    print "<pre>" . htmlspecialchars($d, ENT_QUOTES, 'UTF-8') . "</pre>";
}



/* validate_email STRING
 * Return TRUE if the passed STRING may be a valid email address. 
 * This is derived from Paul Warren's code here,
 *  http://www.ex-parrot.com/~pdw/Mail-RFC822-Address.html
 * as adapted in EvEl (to look only at the addr-spec part of an address --
 * that is, the "foo@bar" bit).
 */
function validate_email ($address) {
    if (preg_match('/^([^()<>@,;:\\".\[\] \000-\037\177\200-\377]+(\s*\.\s*[^()<>@,;:\\".\[\] \000-\037\177\200-\377]+)*|"([^"\\\r\n\200-\377]|\.)*")\s*@\s*[A-Za-z0-9][A-Za-z0-9-]*(\s*\.\s*[A-Za-z0-9][A-Za-z0-9-]*)*$/', $address))
        return true;
    else
        return false;
}


/* validate_postcode POSTCODE
 * Return true is POSTCODE is in the proper format for a UK postcode. Does not
 * require spaces in the appropriate place. */
function validate_postcode ($postcode) {
    // Our test postcode
    if (preg_match("/^zz9\s*9zz$/i", $postcode))
        return true; 
    
    // See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    $in  = 'ABDEFGHJLNPQRSTUWXYZ';
    $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    $thd = 'ABCDEFGHJKSTUW';
    $fth = 'ABEHMNPRVWXY';
    $num = '0123456789';
    $nom = '0123456789';
    $gap = '\s\.';	

    if (preg_match("/^[$fst][$num][$gap]*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$num][$num][$gap]*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num][$gap]*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num][$num][$gap]*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$num][$thd][$gap]*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num][$fth][$gap]*[$nom][$in][$in]$/i", $postcode)) {
        return true;
    } else {
        return false;
    }
}

/* validate_partial_postcode PARTIAL_POSTCODE
 * Return true is POSTCODE is the first part of a UK postcode.  e.g. WC1.
 */
function validate_partial_postcode ($postcode) {
    // Our test postcode
    if (preg_match("/^zz9/i", $postcode))
        return true; 

    // See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    $thd = 'ABCDEFGHJKSTUW';
    $fth = 'ABEHMNPRVWXY';
    $num = '0123456789';

    if (preg_match("/^[$fst][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$num][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$num][$thd]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num][$fth]$/i", $postcode)) {
        return true;
    } else {
        return false;
    }
}

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

/* getmicrotime
 * Return time since the epoch, including fractional seconds. */
function getmicrotime() {
    $mtime = microtime();
    $mtime = explode(" ",$mtime);
    $mtime = $mtime[1] + $mtime[0];

    return $mtime;
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
    $text = preg_replace("/(\S{60})/", "\$1 ", $text);

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
    if (strlen($text) > $length) {

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

/* debug_timestamp
 * Output a timestamp since the page was started. */
$timestamp_last = $timestamp_start = getmicrotime();
function debug_timestamp($comment = false, $extra = null) {
    global $timestamp_last, $timestamp_start;
    $t = getmicrotime();
    if ($comment)
        printf("<!--\n   %s\n    %f seconds since start\n    %f seconds since last\n-->",
                is_null($extra) ? 'TIMESTAMP' : $extra, $t - $timestamp_start, $t - $timestamp_last);
    else
        debug("TIMESTAMP", sprintf("%f seconds since start; %f seconds since last",
                $t - $timestamp_start, $t - $timestamp_last));
    $timestamp_last = $t;
}

/* debug_comment_timestamp [NOTE]
 * As debug_timestamp, but print the timestamp in an HTML comment, whether or
 * not the debug flags are set. If specified, NOTE will be printed in the
 * comment. */
function debug_comment_timestamp($extra = null) {
    debug_timestamp(true, $extra);
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
        $ret = preg_replace("#(<a href='[^']*'>)([^<]{40})[^<]*?</a>#", '$1$2...</a>', $ret);
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
        $tt = strftime('%H:%M', $s);
        $t = time();
        if (strftime('%Y%m%d', $s) == strftime('%Y%m%d', $t))
            $tt = "$tt " . _('today');
        elseif (strftime('%U', $s) == strftime('%U', $t))
            $tt = "$tt, " . strftime('%A', $s);
        elseif (strftime('%Y', $s) == strftime('%Y', $t))
            $tt = "$tt, " . strftime('%A %e %B', $s);
        else
            $tt = "$tt, " . strftime('%a %e %B %Y', $s);
        return $tt;
    }
    if (ctype_digit($s)) {
        $locale_info = localeconv();
        return number_format($s, 0, $locale_info['decimal_point'], $locale_info['thousands_sep']);
    }
    return $s;
}

function spoonerise($s) {
    return preg_replace('#^(.)(.*? )(.)#', '$3$2$1', $s);
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

print "new_url('http://www.microsoft.com', 0, 'fish', 'soup') = '" . new_url('http://www.microsoft.com', 0, 'fish', 'soup')  . "'\n";

print "http_auth_user() = '" . http_auth_user() . "'\n";

print "add_tooltip('fish', '\"soup\"') = '" . add_tooltip('fish', '"soup"') . "'\n";

*/

?>
