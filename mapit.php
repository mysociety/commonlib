<?php
/*
 * mapit.php:
 * Interact with MapIt.  Roughly speaking, postcode lookup of voting
 * areas.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org
 *
 * $Id: mapit.php,v 1.5 2004-11-02 16:23:06 chris Exp $
 * 
 */

include_once('rabx.php');
include_once('votingarea.php');

/* Error codes */
define('MAPIT_BAD_POSTCODE', 1);        /* not in the format of a postcode */
define('MAPIT_POSTCODE_NOT_FOUND', 2);  /* postcode not found */
define('MAPIT_AREA_NOT_FOUND', 3);      /* not a valid voting area id */

$mapit_error_strings = array(
    MAPIT_BAD_POSTCODE          => 'Not in the correct format for a postcode',
    MAPIT_POSTCODE_NOT_FOUND    => 'Postcode not found',
    MAPIT_AREA_NOT_FOUND        => 'Area not found'
);

/* mapit_is_error R
 * Does R (the return value from another MaPit function) indicate an error? */
function mapit_is_error($e) {
    return rabx_is_error($e);
}

/* mapit_strerror CODE
 * Return a human-readable string describing CODE. */
function mapit_strerror($e) {
    global $mapit_error_strings;
    if (!rabx_is_error($e))
        return "Success";
    else
        return $e->text;
}

/* mapit_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function mapit_get_error($e) {
    if (is_array($e))
        return FALSE;
    else
        return mapit_strerror($e);
}

$mapit_client = new RABX_Client("http://" . OPTION_MAPIT_HOST . ":" . OPTION_MAPIT_PORT . OPTION_MAPIT_PATH);

/* mapit_get_voting_areas POSTCODE
 * On success, return an array mapping voting/administrative area type to
 * voting area ID. On failure, returns an error code. */
function mapit_get_voting_areas($postcode) {
    global $mapit_client;
    debug("MAPIT", "Looking up areas for postcode $postcode");
    $result = $mapit_client->call('MaPit.get_voting_areas', array($postcode));
    debug("MAPITRESULT", "Result is:", $result);
    return $result;
}

/* mapit_get_voting_area_info ID
 * On success, returns an array giving information about the
 * voting/administrative area ID. This array contains elements type, the type
 * of the area (e.g. "VA_CTY"); and name, the name of the area (e.g., "Norfolk
 * County Council"). On failure, returns an error code. */
function mapit_get_voting_area_info($va_id) {
    global $mapit_client;
    debug("MAPIT", "Looking up info on area $va_id");
    $result = $mapit_client->call('MaPit.get_voting_area_info', array($va_id));
    debug("MAPITRESULT", "Result is:", $result);
    return $result;
}

/* mapit_get_voting_areas_info ARRAY
 */
function mapit_get_voting_areas_info($array) {
    global $mapit_client;
    debug("MAPIT", "Looking up info on areas");
    $result = $mapit_client->call('MaPit.get_voting_areas_info', array($array));
    debug("MAPITRESULT", "Result is:", $result);
    return $result;
}

?>
