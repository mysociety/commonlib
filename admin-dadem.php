<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-dadem.php,v 1.1 2004-11-19 12:25:44 francis Exp $
 * 
 */

require_once "dadem.php";

class ADMIN_PAGE_DADEM {
    function ADMIN_PAGE_DADEM () {
        $this->id = "dadem";
        $this->name = "DaDem";
        $this->navname = "DaDem the Reps";
    }

    function display($self_link) {
        global $fyr_error_message;

        $form = new HTML_QuickForm('adminDaDemForm', 'get', $self_link);

       // General Statistics
        $form->addElement('header', '', 'General Statistics');
        $stats = dadem_admin_get_stats();
        if ($fyr_error_message = dadem_get_error($stats)) template_show_error();
        $form->addElement('static', 'stats', "Representatives: ",  $stats['representative_count']);
        $form->addElement('static', 'stats', "Voting Areas: ", $stats['area_count']);

        $form->addElement('static', 'stats', "Fax or Email Coverage: ", 
                round(100*$stats['either_present']/$stats['representative_count'],2) .  "% (" . $stats['either_present'] . ")");
        $form->addElement('static', 'stats', "Email Coverage: ", 
                round(100*$stats['email_present']/$stats['representative_count'],2) .  "% (" . $stats['email_present'] . ")");
        $form->addElement('static', 'stats', "Fax Coverage: ", 
                round(100*$stats['fax_present']/$stats['representative_count'],2) .  "% (" . $stats['fax_present'] . ")");
        
/*
        // Counts by Area Type
        $form->addElement('header', '', 'Counts by Area Type');
        $html = "<table>";
        foreach ($stats as $k=>$v) {
            preg_match("/area_count_([A-Z]+)/", $k, $matches);
            if ($matches) {
                $html .= "<tr><td>" . $matches[1] . "</td><td>$v</td></tr>\n";
            }
        }
        $html .= "</table>";
        */

        // DaDem Browser
        $form->addElement('header', '', 'Representatives Viewer');

        $va_id = get_http_var('va_id');
        $rep_id = get_http_var('rep_id');
        if ($rep_id == "" && $va_id == "")
            $va_id = 1;
        if ($va_id != "") {
            $reps = dadem_get_representatives($va_id);
            if ($fyr_error_message = dadem_get_error($reps)) template_show_error();
            $reps = array_values($reps);
            $html .= "<b>$va_id: Voting Area</b> ";
            $html .= "<a href=\"?page=mapit&va_id=$va_id\">Browse in MaPit</a><br>";
        } else if ($rep_id != "") {
            $reps = array($rep_id);
        }

        $info = dadem_get_representatives_info($reps);
        if ($fyr_error_message = dadem_get_error($info)) template_show_error();

        foreach ($info as $rep => $repinfo) {
            $html .= "<b>$rep: Representative</b><br>";
            foreach ($repinfo as $k=>$v) {
                $html .= "$k=$v ";
            }
            $html .= "<br>";
        }

        $form->addElement('static', 'bytype', null, $html);

         admin_render_form($form);
    }
}

?>
