<?php
/*
 * mapit.php:
 * Interact with MapIt.  Roughly speaking, postcode lookup of voting
 * areas.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org
 *
 * $Id: mapit.php,v 1.7 2004-11-19 12:25:44 francis Exp $
 * 
 */

include_once('rabx.php');
include_once('votingarea.php');

/* Error codes */
define('MAPIT_BAD_POSTCODE', 2001);        /* not in the format of a postcode */
define('MAPIT_POSTCODE_NOT_FOUND', 2002);  /* postcode not found */
define('MAPIT_AREA_NOT_FOUND', 2003);      /* not a valid voting area id */

/* mapit_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function mapit_get_error($e) {
    if (!rabx_is_error($e))
        return FALSE;
    else
        return $e->text;
}

$mapit_client = new RABX_Client(OPTION_MAPIT_URL);

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

/* mapit_get_voting_area_children ID
 */
function mapit_get_voting_area_children($id) {
    global $mapit_client;
    $result = $mapit_client->call('MaPit.get_voting_area_children', array($id));
    return $result;
}


/* mapit_admin_get_stats
 */
function mapit_admin_get_stats() {
    global $mapit_client;
    $result = $mapit_client->call('MaPit.admin_get_stats', array($array));
    return $result;
}
?>
