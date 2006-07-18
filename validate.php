<?php
/*
 * utility.php:
 * General utility functions. Taken from the TheyWorkForYou.com source
 * code, and licensed under a BSD-style license.
 * 
 * Mainly: Copyright (c) 2003-2004, FaxYourMP Ltd 
 * Parts are: Copyright (c) 2004 UK Citizens Online Democracy
 *
 * $Id: validate.php,v 1.2 2006-07-18 08:13:52 francis Exp $
 * 
 */

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
    if (preg_match("/^zz9\s*9z[zy]$/i", $postcode))
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
 * Return true is POSTCODE is the first part of a UK postcode.  e.g. WC1. */
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
