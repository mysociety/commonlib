<?php
/*
 * dadem.php:
 * Interact with DaDem. Roughly speaking, look up representatives in
 * office for a voting area.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org
 *
 * $Id: dadem.php,v 1.4 2004-10-28 11:00:03 chris Exp $
 * 
 */

include_once('rabx.php');
include_once('utility.php');
include_once('votingarea.php');

/* Error codes */
define('DADEM_UNKNOWN_AREA', 1);        /* unknown area */
define('DADEM_REP_NOT_FOUND', 2);       /* unknown representative id */
define('DADEM_AREA_WITHOUT_REPS', 3);   /* not an area for which representatives are returned */

$dadem_error_strings = array(
    DADEM_UNKNOWN_AREA      =>  'Unknown voting area',
    DADEM_REP_NOT_FOUND     =>  'Representative not found',
    DADEM_AREA_WITHOUT_REPS =>  'Not an area type for which representatives are returned'
);

define('DADEM_CONTACT_FAX', 101);
define('DADEM_CONTACT_EMAIL', 102);

/* dadem_is_error R
 * Does R (the return value from another DaDem function) indicate an error? */
function dadem_is_error($e) {
//    return is_integer($e);
    return rabx_is_error($e);
}

/* dadem_strerror CODE
 * Return a human-readable string describing CODE. */
function dadem_strerror($e) {
    global $dadem_error_strings;
    if (!rabx_is_error($e))
        return "Success";
    else
        return $e->text;
}

/* dadem_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function dadem_get_error($e) {
    if (is_array($e))
        return FALSE;
    else
        return dadem_strerror($e);
}

$dadem_client = new RABX_Client("http://" . OPTION_DADEM_HOST . ":" . OPTION_DADEM_PORT . OPTION_DADEM_PATH);

/* dadem_get_representatives VOTING_AREA_ID
 * Return an array of IDs for the representatives for the given voting
 * area on success, or an error code on failure. */
function dadem_get_representatives($va_id) {
    global $dadem_client;
    debug("DADEM", "Looking up representatives for voting area id $va_id");
//    $result = sxr_call(OPTION_DADEM_HOST, OPTION_DADEM_PORT, OPTION_DADEM_PATH, 'DaDem.get_representatives', array($va_id));
    $result = $dadem_client->call('DaDem.get_representatives', array($va_id));
    debug("DADEMRESULT", "Result is:", $result);
    return $result;
}

/* dadem_get_representative_info ID
 * On success, returns an array giving information about the representative
 * with the given ID. This array contains elements type, the type of the area
 * for which they're elected (and hence what type of representative they are);
 * name, their name; contact_method, either 'fax' or 'email', and either an
 * element 'email' or 'fax' giving their address or number respectively. 
 * voting_area, the id of the voting area they represent.
 * On failure, returns an error code. */
function dadem_get_representative_info($rep_id) {
    global $dadem_client;
    debug("DADEM", "Looking up info on representative id $rep_id");
    $result = $dadem_client->call('DaDem.get_representative_info', array($rep_id));
    return $result;
}

/* dadem_get_representatives_info ARRAY
 * Return an associative array giving information on all the representatives
 * whose IDs are given in ARRAY. */
function dadem_get_representatives_info($array) {
    global $dadem_client;
    debug("DADEM", "Looking up info on representatives");
    $result = $dadem_client->call('DaDem.get_representatives_info', array($array));
    return $result;
}

?>
