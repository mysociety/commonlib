<?php
/*
 * emailaddress.php:
 * Test validity of email addresses.
 *
 * This is derived from Paul Warren's code here,
 *  http://www.ex-parrot.com/~pdw/Mail-RFC822-Address.html
 * as adapted in EvEl (to look only at the addr-spec part of an address --
 * that is, the "foo@bar" bit).
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: emailaddress.php,v 1.1 2005-04-18 14:54:23 chris Exp $
 * 
 */

/* emailaddress_is_valid ADDRESS
 * Is ADDRESS a valid address? */
function emailaddress_is_valid($address) {
    if (preg_match('/^([^()<>@,;:\\".\[\] \000-\037\177\200-\377]+(\s*\.\s*[^()<>@,;:\\".\[\] \000-\037\177\200-\377]+)*|"([^"\\\r\n\200-\377]|\.)*")\s*@\s*[A-Za-z0-9][A-Za-z0-9-]*(\s*\.\s*[A-Za-z0-9][A-Za-z0-9-]*)*$/', $address))
        return true;
    else
        return false;
}

/*
foreach (array('chris', 'chris@ex-parrot.com', 'chris@[127.0.0.1]', 'fish soup @octopus', 'chris@_.com') as $a) {
    print "$a -> " . (emailaddress_is_valid($a) ? 'VALID' : 'NOT VALID') . "\n";
}
*/

?>
