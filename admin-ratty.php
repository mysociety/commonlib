<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-ratty.php,v 1.1 2004-11-11 12:24:47 francis Exp $
 * 
 */

class ADMIN_PAGE_RATTY {
    function ADMIN_PAGE_RATTY () {
        $this->id = "ratty";
        $this->name = "Ratty";
        $this->navname = "Ratty the Rate Limiter";
    }

    function display() {
        $form = new HTML_QuickForm('adminRattyForm', 'get', 'index');

        $form->addElement('header', '', 'Rate Limiting Rules');
        $form->addElement('text', 'bah', null, array('size' => 10, 'maxlength' => 255));
        $form->addElement('submit', 'go', 'Boo');
        $form->addRule('bah', 'Please enter your bah', 'required', null, null);

        admin_render_form($form);
    }
}

?>
