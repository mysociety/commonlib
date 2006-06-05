<?php
/*
 * debug.php:
 * Debugging functions.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: debug.php,v 1.2 2006-06-05 18:51:26 chris Exp $
 * 
 */

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
                debug_vardump($complex_variable);
            }
            print "</p>\n";	
		}
	}
}

/* debug_vardump VARIABLE
 * Dump VARIABLE to the page, properly escaped and wrapped in <pre> tags. */
function debug_vardump($blah) {
   /* Miserable. We need to encode entities in the output, which means messing
    * about with output buffering. */
   ob_start();
   var_dump($blah);
   $d = ob_get_contents();
   ob_end_clean();
   print "<pre>" . htmlspecialchars($d, ENT_QUOTES, 'UTF-8') . "</pre>";
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

?>
