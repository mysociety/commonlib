<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-configinfo.php,v 1.1 2004-11-18 23:42:57 francis Exp $
 * 
 */

class ADMIN_PAGE_CONFIGINFO {
    function ADMIN_PAGE_CONFIGINFO () {
        $this->id = "confinfo";
        $this->name = "Config";
        $this->navname = "Configuration Values";
    }

    function run($command) {
        ob_start();
        passthru($command);
        $ret = ob_get_contents();
        ob_end_clean();
        return "<tr><td><p><pre>$ret</pre></td></tr>";
    }

    function display($self_link) {
        $form = new HTML_QuickForm('adminConfigInfoForm', 'get', $self_link);

        $consts = get_defined_constants();

        $form->addElement('header', '', 'Configuration Settings (from conf/general)');
        foreach ($consts as $const => $value) {
            if (preg_match("/^OPTION_/", $const)) {
                $form->addElement('static', "static$const", null, "$const = $value");
            }
        }

        admin_render_form($form);
     }
}

?>
