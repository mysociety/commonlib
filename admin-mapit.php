<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-mapit.php,v 1.2 2004-11-22 12:22:39 francis Exp $
 * 
 */

require_once "mapit.php";

class ADMIN_PAGE_MAPIT {
    function ADMIN_PAGE_MAPIT () {
        $this->id = "mapit";
        $this->name = "MaPit";
        $this->navname = "MaPit the Postcoder";
    }

    function display($self_link) {
        $form = new HTML_QuickForm('adminMaPitForm', 'get', $self_link);

        // MaPit Browser

        function render_area($self_link, $va_id, $info) {
            return "<a href=\"$self_link&va_id=" . $va_id . "\">$va_id: " .  $info['name'] . " (". $info['type_name'] . ")</a>\n";
        }

        $form->addElement('header', '', 'Voting Area Browser');

        $va_id = get_http_var('va_id');
        $pc = get_http_var('pc');
        if ($pc == "" && $va_id == "")
            $va_id = 1;
        if ($va_id != "") {
            $info = mapit_get_voting_area_info($va_id);
            mapit_check_error($info);

            $html .= "<b>".$va_id . ": " . $info['name'] .  " (".$info['type_name'].")</b> ";
            $html .= "<a href=\"?page=dadem&va_id=$va_id\">Browse in DaDem</a>";
            $html .= "<br>";
            foreach ($info as $k=>$v) {
                $html .= "$k=$v ";
            }

            $html .= "<br>Parent: ";
            if ($info['parent_area_id']) {
                $parent_info = mapit_get_voting_area_info($info['parent_area_id']);
                mapit_check_error($parent_info);
                $html .= render_area($self_link, $info['parent_area_id'], $parent_info);
            } else {
                $html .= "None";
            }
            $children = mapit_get_voting_area_children($va_id);
            mapit_check_error($children);
            $html .= "<br>Children: ";
            if (count($children) > 0) {
                $children_info = mapit_get_voting_areas_info($children);
                mapit_check_error($children_info);
                foreach ($children_info as $child=>$child_info) {
                    $html .= "<br>";
                    $html .= render_area($self_link, $child, $child_info);
                }
                $html .= "<br>";
            } else {
                $html .= "None";
            }
        } else if ($pc != "") {
            $pc = strtoupper($pc);
            $html .= "<b>$pc</b><br>";

            $voting_areas = mapit_get_voting_areas($pc);
            mapit_check_error($voting_areas);
            $areas = array_values($voting_areas);
            $areas_info = mapit_get_voting_areas_info($areas);
            mapit_check_error($areas_info);
            foreach ($areas_info as $area=>$area_info) {
                $html .= render_area($self_link, $area, $area_info);
                $html .= "<br>";
            }

        }
        $form->addElement('static', 'bytype', null, $html);

        $buttons[0] =& HTML_QuickForm::createElement('text', 'pc', null, array('size' => 10, 'maxlength' => 255));
        $buttons[1] =& HTML_QuickForm::createElement('submit', 'go', 'go postcode');
        $form->addElement('hidden', 'page', $this->id);
        $form->addGroup($buttons, 'stuff', null, '&nbsp', false);

        // General Statistics
        $form->addElement('header', '', 'General Statistics');
        $stats = mapit_admin_get_stats();
        $form->addElement('static', 'stats', null, "Areas: " . $stats['area_count']);
        $form->addElement('static', 'stats', null, "Postcodes: " .  $stats['postcode_count']);
        
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
        $form->addElement('static', 'bytype', null, $html);

        admin_render_form($form);
    }
}

?>
