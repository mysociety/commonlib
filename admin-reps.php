<?php
/*
 * Representatives admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-reps.php,v 1.11 2005-02-10 11:51:48 francis Exp $
 * 
 */

require_once "dadem.php";
require_once "mapit.php";

class ADMIN_PAGE_REPS {
    function ADMIN_PAGE_REPS () {
        $this->id = "reps";
        $this->name = "Reps";
        $this->navname= "Representative Data";
    }

    function render_reps($self_link, $reps) {
        $html = "";
        $info = dadem_get_representatives_info($reps);
        dadem_check_error($info);

        foreach ($reps as $rep) {
            $repinfo = $info[$rep];
            if ($repinfo['edited']) {
                $html .= "<i>edited</i> ";
            }
            $html .= "<a href=\"$self_link&pc=" .  urlencode(get_http_var('pc')). "&rep_id=" . $rep .  "\">" . $repinfo['name'] . " (". $repinfo['party'] . ")</a> \n";
            $html .= "prefer " . $repinfo['method'];
            if ($repinfo['email']) 
                $html .= ", " .  $repinfo['email'];
            if ($repinfo['fax']) 
                $html .= ", " .  $repinfo['fax'];
            $html .= "<br>";
        }
        return $html;
    }

    function display($self_link) {
        // Input data
        $rep_id = get_http_var('rep_id');
        if (get_http_var('gos')) {
            $search = get_http_var('search');
            $rep_id = null;
        }
        else
            $search = null;
        $ds_va_id = get_http_var('ds_va_id');
        if (!$rep_id && $ds_va_id) {
            // Democratic services
            $ds_vainfo = dadem_get_representatives($ds_va_id);
            dadem_check_error($ds_vainfo);
            $rep_id = $ds_vainfo[0];
        }
        $pc = get_http_var('pc');
        if (get_http_var('gopc')) {
            $rep_id = null;
        }
        if (get_http_var('cancel') != "") 
            $rep_id = null;
        if (get_http_var('done') != "") {
            $newdata['name'] = get_http_var('name');
            $newdata['party'] = get_http_var('party');
            $newdata['method'] = get_http_var('method');
            $newdata['email'] = get_http_var('email');
            $newdata['fax'] = get_http_var('fax');
            $result = dadem_admin_edit_representative($rep_id, $newdata, http_auth_user(), get_http_var('note'));
            dadem_check_error($result);
            print "<p><i>Successfully updated representative ". htmlspecialchars($rep_id) . "</i></i>";
            $rep_id = null;
        }

        // Postcode and search box
        $form = new HTML_QuickForm('adminRepsSearchForm', 'get', $self_link);
        $form->addElement('header', '', 'Search');
        $buttons[] =& HTML_QuickForm::createElement('text', 'pc', null, array('size' => 10, 'maxlength' => 255));
        $buttons[] =& HTML_QuickForm::createElement('submit', 'gopc', 'go postcode');
        $buttons[] =& HTML_QuickForm::createElement('text', 'search', null, array('size' => 20, 'maxlength' => 255));
        $buttons[] =& HTML_QuickForm::createElement('submit', 'gos', 'search');
        $form->addElement('hidden', 'page', $this->id);
        $form->addGroup($buttons, 'stuff', null, '&nbsp', false);
        admin_render_form($form);

        // Conditional parts: 
        $form = new HTML_QuickForm('adminRepsEditForm', 'get', $self_link);
        $form->addElement('hidden', 'page', $this->id);
        if ($rep_id) {
            // Edit representative
            $repinfo = dadem_get_representative_info($rep_id);
            dadem_check_error($repinfo);
            $vainfo = mapit_get_voting_area_info($repinfo['voting_area']);
            mapit_check_error($vainfo);
            if ($vainfo['parent_area_id']) {
                $parentinfo = mapit_get_voting_area_info($vainfo['parent_area_id']);
                mapit_check_error($parentinfo);
            } else 
                $parentinfo = null;
            $rephistory = dadem_get_representative_history($rep_id);
            dadem_check_error($rephistory);
            // Reverse postcode lookup
            if (!$pc) {
                $pc = mapit_get_example_postcode($repinfo['voting_area']);
                mapit_check_error($pc);
                $form->addElement('static', 'note1', null, "Example postcode for testing: " . htmlentities($pc));
            }

            $form->setDefaults(
                array('name' => $repinfo['name'],
                'party' => $repinfo['party'],
                'method' => $repinfo['method'],
                'email' => $repinfo['email'],
                'fax' => $repinfo['fax']));
    
            // Councillor types are not edited here, but in match.cgi interface
            global $va_council_child_types;
            $editable_here = true;
            if (in_array($vainfo['type'], $va_council_child_types)) {
                $editable_here = false;
            }
            $readonly = $editable_here ? null : "readonly";

            $form->addElement('header', '', 'Edit Representative');
            if ($editable_here) {
                $form->addElement('static', 'note1', null, "
                Edit only the values which you need to.  Blank to return to default.");
            }
            $form->addElement('static', 'office', 'Office:',
                htmlspecialchars($vainfo['rep_name']) . " for " . 
                htmlspecialchars($vainfo['name']) . " " . htmlspecialchars($vainfo['type_name']) . 
                ($parentinfo ? " in " . 
                htmlspecialchars($parentinfo['name']) . " " . htmlspecialchars($parentinfo['type_name']) : "" ));
            $form->addElement('text', 'name', "Full name:", array('size' => 60, $readonly => 1));
            $form->addElement('text', 'party', "Political party:", array('size' => 60, $readonly => 1));
            $form->addElement('static', 'note2', null, "Make sure you
            update contact method when you change email or fax
            numbers.");
            $form->addElement('select', 'method', "Contact method to use:", 
                    array(
                        'either' => 'Fax or Email', 'fax' => 'Fax only', 
                        'email' => 'Email only',
                        'shame' => "Shame! Doesn't want contacting",
                        'via' => 'Contact via electoral body (e.g. Democratic Services)',
                        'unknown' => "We don't know contact details"
                    ),
                    array($readonly => 1));
            $form->addElement('text', 'email', "Email address:", array('size' => 60, $readonly => 1));
            $form->addElement('text', 'fax', "Fax number:", array('size' => 60, $readonly => 1));
            $form->addElement('textarea', 'note', "Note to add to log:
            (where new data was from etc.)", array('rows' => 3, 'cols' => 60, $readonly => 1));
            $form->addElement('hidden', 'pc', $pc);
            $form->addElement('hidden', 'rep_id', $rep_id);

            if ($editable_here) {
                $finalgroup[] = &HTML_QuickForm::createElement('submit', 'done', 'Done');
                $finalgroup[] = &HTML_QuickForm::createElement('submit', 'cancel', 'Cancel');
                $form->addGroup($finalgroup, "finalgroup", "",' ', false);
            } else {
                $form->addElement('static', 'note3', null, 
                    '<a href="https://secure.mysociety.org/admin/services/match.cgi?page=councilinfo;area_id='
                    . $vainfo['parent_area_id'] . '">To edit Councillors please use the match.cgi interface</a>'.
                    '<br><a href="'.$self_link.'&ds_va_id='
                    . $vainfo['parent_area_id'] . '">... or edit Democratic Services for this council</a>');
            }
    
            $form->addElement('header', '', 'Historical Changes (each
                relative to imported data)');
            $html = "<table border=1>";
            $html .= "<th>Order</th><th>Date</th><th>Editor</th><th>Note</th>
                <th>Name</th> <th>Party</th> <th>Method</th> <th>Email</th>
                <th>Fax</th>";

            foreach ($rephistory as $row) {
                $html .= "<tr>";
                $html .= "<td>" . $row['order_id'] . "</td>\n";
                $html .= "<td>" . strftime('%Y-%m-%d %H:%M:%S', $row['whenedited']) . "</td>\n";
                $html .= "<td>" . $row['editor'] . "</td>\n";
                $html .= "<td>" . $row['note'] . "</td>\n";
                $html .= "<td>" . $row['name'] . "</td>\n";
                $html .= "<td>" . $row['party'] . "</td>\n";
                $html .= "<td>" . $row['method'] . "</td>\n";
                $html .= "<td>" . $row['email'] . "</td>\n";
                $html .= "<td>" . $row['fax'] . "</td>\n";
                $html .= "</tr>";
            }
            $html .= "</table>";
            $form->addElement('static', 'bytype', null, $html);
        } else if ($search) {
            // Search reps
            $reps = dadem_search_representatives($search);
            dadem_check_error($reps);
            $html = $this->render_reps($self_link, $reps);
            $form->addElement('static', 'bytype', null, $html);
        } else if ($pc) {
            // Postcode search
            $voting_areas = mapit_get_voting_areas($pc);
            mapit_check_error($voting_areas);
            $areas = array_values($voting_areas);
            $areas_info = mapit_get_voting_areas_info($areas);
            mapit_check_error($areas_info);
            $html = "";
            // Display in order council, ward, council, ward...
            global $va_display_order, $va_inside;
            $our_order = array();
            foreach ($va_display_order as $row) {
                if (!is_array($row))
                    $row = array($row);
                $our_order[] = $va_inside[$row[0]];
                foreach ($row as $va_type) {
                    $our_order[] = $va_type;
                }
            }
            // Render everything in the order
            foreach ($our_order as $va_type) {
                foreach ($areas_info as $area=>$area_info) {
                    if ($va_type <> $area_info['type']) 
                        continue;
                    $va_id = $area;

                    // One voting area
                    $reps = dadem_get_representatives($va_id);
                    dadem_check_error($reps);
                    $reps = array_values($reps);
                    $html .= "<p><b>" . $area_info['name'] . " (" .  $area_info['type_name'] . ") </b></p>"; 
                    $html .= $this->render_reps($self_link, $reps);
                }
            }
            $form->addElement('static', 'bytype', null, $html);
        } else {
            // General Statistics

            // MaPit
            $form->addElement('header', '', 'Postcode/Area Statistics (MaPit)');
            $mapitstats = mapit_admin_get_stats();
            $form->addElement('static', 'mapitstats', "Areas: ", $mapitstats['area_count']);
            $form->addElement('static', 'mapitstats', "Postcodes: ",  $mapitstats['postcode_count']);
            
            // DaDem
            $form->addElement('header', '', 'Representative Statistics (DaDem)');
            $dademstats = dadem_admin_get_stats();
            dadem_check_error($dademstats);
            $form->addElement('static', 'dademstats', "Representatives: ",  $dademstats['representative_count']);
            $form->addElement('static', 'dademstats', "Voting Areas: ", $dademstats['area_count']);

            $form->addElement('static', 'dademstats', "Fax or Email Coverage: ", 
                    round(100*$dademstats['either_present']/$dademstats['representative_count'],2) .  "% (" . $dademstats['either_present'] . ")");
            $form->addElement('static', 'dademstats', "Email Coverage: ", 
                    round(100*$dademstats['email_present']/$dademstats['representative_count'],2) .  "% (" . $dademstats['email_present'] . ")");
            $form->addElement('static', 'dademstats', "Fax Coverage: ", 
                    round(100*$dademstats['fax_present']/$dademstats['representative_count'],2) .  "% (" . $dademstats['fax_present'] . ")");

            // MaPit counts by Area Type
            $form->addElement('header', '', 'MaPit Counts by Area Type');
            $html = "<table>";
            foreach ($mapitstats as $k=>$v) {
                preg_match("/area_count_([A-Z]+)/", $k, $matches);
                if ($matches) {
                    $html .= "<tr><td>" . $matches[1] . "</td><td>$v</td></tr>\n";
                }
            }
            $html .= "</table>";
            $form->addElement('static', 'bytype', null, $html);
        }

        admin_render_form($form);
   }
}


?>
