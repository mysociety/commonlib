<?php
/*
 * dadem.php:
 * Interact with DaDem. Roughly speaking, look up representatives in
 * office for a voting area.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org
 *
 * $Id: dadem.php,v 1.11 2004-12-20 22:46:07 francis Exp $
 * 
 */

include_once('rabx.php');
include_once('utility.php');
include_once('votingarea.php');

/* Error codes */
define('DADEM_UNKNOWN_AREA', 3001);        /* unknown area */
define('DADEM_REP_NOT_FOUND', 3002);       /* unknown representative id */
define('DADEM_AREA_WITHOUT_REPS', 3003);   /* not an area for which representatives are returned */

define('DADEM_CONTACT_FAX', 101);
define('DADEM_CONTACT_EMAIL', 102);

/* dadem_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function dadem_get_error($e) {
    if (!rabx_is_error($e))
        return FALSE;
    else
        return $e->text;
}

/* dadem_check_error R
 * If R indicates failure, displays error message and stops procesing.
 */
function dadem_check_error($data) {
    if ($error_message = dadem_get_error($data)) {
        template_show_error($error_message);
    }
}

$dadem_client = new RABX_Client(OPTION_DADEM_URL);

/* dadem_get_representatives VOTING_AREA_ID
 * Return an array of IDs for the representatives for the given voting
 * area on success, or an error code on failure. */
function dadem_get_representatives($va_id) {
    global $dadem_client;
    debug("DADEM", "Looking up representatives for voting area id $va_id");
    $result = $dadem_client->call('DaDem.get_representatives', array($va_id));
    debug("DADEMRESULT", "Result is:", $result);
    return $result;
}

/* dadem_search_representatives STRING
 * Return an array of IDs for the representatives whose names, party
 * or contact details containt the given search string.  Case
 * insensitive. */
function dadem_search_representatives($query) {
    global $dadem_client;
    $result = $dadem_client->call('DaDem.search_representatives', array($query));
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
    debug("DADEMRESULT", "Result is:", $result);
    return $result;
}

/* dadem_get_representatives_info ARRAY
 * Return an associative array giving information on all the representatives
 * whose IDs are given in ARRAY. */
function dadem_get_representatives_info($array) {
    global $dadem_client;
    debug("DADEM", "Looking up info on representatives");
    $result = $dadem_client->call('DaDem.get_representatives_info', array($array));
    debug("DADEMRESULT", "Result is:", $result);
    return $result;
}

/* dadem_get_representative_history ID
 * On success, returns an array of hashes about changes in contact
 * details for the representative with the given ID.  */
function dadem_get_representative_history($rep_id) {
    global $dadem_client;
    $result = $dadem_client->call('DaDem.get_representative_history', array($rep_id));
    return $result;
}

/* dadem_get_stats
 * Return an associative array giving statistics about DaDem's 
 * database */
function dadem_admin_get_stats() {
    global $dadem_client;
    $result = $dadem_client->call('DaDem.admin_get_stats', array());
    return $result;
}

/* admin_edit_representative ID NEWDATA EDITOR NOTE
 * Alter data for a representative.  ID is the id to change,
 * NEWDATA hash of new columns.  EDITOR name of who altered
 * it.  NOTE is a comment as to why they did so.  */
function dadem_admin_edit_representative($id, $newdata, $editor, $note) {
    global $dadem_client;
    $result = $dadem_client->call('DaDem.admin_edit_representative', array($id, $newdata, $editor, $note));
    return $result;
}

?>
