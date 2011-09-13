<?php
/*
 * Server info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-serverinfo.php,v 1.5 2005-02-21 11:37:32 francis Exp $
 * 
 */

class ADMIN_PAGE_SERVERINFO {
    function ADMIN_PAGE_SERVERINFO () {
        $this->id = "serverinfo";
        $this->navname = "Server Information";
    }

    function run($command) {
        ob_start();
        passthru($command);
        $ret = ob_get_contents();
        ob_end_clean();
        return "<pre>$ret</pre>";
    }

    function display($self_link) {
        print '<h2>System Name</h2>';
        print $this->run("uname -a | fmt");
        print '<h2>Time, Uptime, Logins and Load (over last 1, 5, 15 mins)</h2>';
        print $this->run("uptime");
        print '<h2>Disk Space</h2>';
        print $this->run("df -h");
        print '<h2>Recent Logins</h2>';
        print $this->run("who");
        print '<h2>Network Interfaces</h2>';
        print $this->run("/sbin/ifconfig");
    }
}

