<?php
/*
 * Config info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-configinfo.php,v 1.3 2005-02-21 11:37:32 francis Exp $
 * 
 */

class ADMIN_PAGE_CONFIGINFO {
    function ADMIN_PAGE_CONFIGINFO () {
        $this->id = "confinfo";
        $this->navname = "Configuration Values";
    }

    function display($self_link) {
        print '<ul>';
        $consts = get_defined_constants();
        foreach ($consts as $const => $value) {
            if (preg_match("/^OPTION_/", $const)) {
                print "<li>$const = $value";
            }
        }
        print '</ul>';
     }
}

