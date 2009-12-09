<?php
/*
 * utility.php:
 * General utility functions. Taken from the TheyWorkForYou.com source
 * code, and licensed under a BSD-style license.
 * 
 * Mainly: Copyright (c) 2003-2004, FaxYourMP Ltd 
 * Parts are: Copyright (c) 2004 UK Citizens Online Democracy
 *
 * $Id: validate.php,v 1.7 2009-11-19 12:47:43 matthew Exp $
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
    $num0 = '123456789'; # Technically allowed in spec, but none exist
    $num = '0123456789';
    $nom = '0123456789';

    if (preg_match("/^[$fst][$num0]\s*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$num0][$num]\s*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num]\s*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num0][$num]\s*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$num0][$thd]\s*[$nom][$in][$in]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num0][$fth]\s*[$nom][$in][$in]$/i", $postcode)) {
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
    $num0 = '123456789'; # Technically allowed in spec, but none exist
    $num = '0123456789';

    if (preg_match("/^[$fst][$num0]$/i", $postcode) ||
        preg_match("/^[$fst][$num0][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num0][$num]$/i", $postcode) ||
        preg_match("/^[$fst][$num0][$thd]$/i", $postcode) ||
        preg_match("/^[$fst][$sec][$num0][$fth]$/i", $postcode)) {
        return true;
    } else {
        return false;
    }
}

/* validate_easily_mistyped_postcode POSTCODE
 * If we can work out an obvious mistyping (e.g. 0 -> O or 1 -> I),
 * return the correct postcode. Otherwise return null. POSTCODE
 * should already be canonicalised. */
function validate_easily_mistyped_postcode($pc) {
    $changed = false;
    if (strlen($pc) < 6) return false;

    # First character of postcode can never be a number
    if ($pc[0] == '0') { $pc[0] = 'O'; $changed = true; }
    elseif ($pc[0] == '1') { $pc[0] = 'I'; $changed = true; }

    # Second character can never be 0
    if ($pc[1] == '0') { $pc[1] = 'O'; $changed = true; }

    # 3rd and 4th characters of postcode can never be O or I
    if ($pc[2] == 'O') { $pc[2] = '0'; $changed = true; }
    elseif ($pc[2] == 'I') { $pc[2] = '1'; $changed = true; }
    if ($pc[3] == 'O') { $pc[3] = '0'; $changed = true; }
    elseif ($pc[3] == 'I') { $pc[3] = '1'; $changed = true; }

    # First character of inward part is always a number
    $pos = strlen($pc)-3;
    if ($pc[$pos] == 'O') { $pc[$pos] = '0'; $changed = true; }
    elseif ($pc[$pos] == 'I') { $pc[$pos] = '1'; $changed = true; }

    if ($changed) return $pc;
    return null;
}
