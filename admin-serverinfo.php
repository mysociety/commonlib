<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-serverinfo.php,v 1.2 2004-11-15 16:51:30 fyr Exp $
 * 
 */

class ADMIN_PAGE_SERVERINFO {
    function ADMIN_PAGE_SERVERINFO () {
        $this->id = "serverinfo";
        $this->name = "Server Info";
        $this->navname = "Server Information";
    }

    function run($command) {
        ob_start();
        passthru($command);
        $ret = ob_get_contents();
        ob_end_clean();
        return "<tr><td><p><pre>$ret</pre></td></tr>";
    }

    function display($self_link) {
        $form = new HTML_QuickForm('adminRattyForm', 'get', $self_link);

        $form->addElement('header', '', 'System Name');
        $form->addElement('html', $this->run("uname -a | fmt"));
        $form->addElement('header', '', 'Time, Uptime, Logins and Load (over last 1, 5, 15 mins)');
        $form->addElement('html', $this->run("uptime"));
        $form->addElement('header', '', 'Disk Space');
        $form->addElement('html', $this->run("df -h"));
        $form->addElement('header', '', 'Recent Logins');
        $form->addElement('html', $this->run("who"));
        $form->addElement('header', '', 'Network Interfaces');
        $form->addElement('html', $this->run("/sbin/ifconfig"));

        admin_render_form($form);
 }
}

?>
