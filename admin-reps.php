<?php
/*
 * Representatives admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-reps.php,v 1.6 2005-01-12 17:40:58 francis Exp $
 * 
 */

require_once "dadem.php";
require_once "mapit.php";

class ADMIN_PAGE_REPS {
    function ADMIN_PAGE_REPS () {
        $this->id = "reps";
        $this->name = "Reps";
        $this->navname = "Representative Data";
    }

    function render_reps($self_link, $reps) {
        $html = "";
        $info = dadem_get_representatives_info($reps);
        dadem_check_error($info);

        foreach ($info as $rep => $repinfo) {
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
        $form = new HTML_QuickForm('adminMaPitForm', 'post', $self_link);

        // Input data
        if (get_http_var('gos'))
            $search = get_http_var('search');
        else
            $search = null;
        if (get_http_var('gopc') or (!isset($search)))
            $pc = get_http_var('pc');
        else 
            $pc = null;
        $rep_id = get_http_var('rep_id');
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
            print "<p><i>Successfully updated representative $rep_id</i></i>";
            $rep_id = null;
        }

        // Postcode and search box
        $form->addElement('header', '', 'Search');
        $buttons[] =& HTML_QuickForm::createElement('text', 'pc', null, array('size' => 10, 'maxlength' => 255));
        $buttons[] =& HTML_QuickForm::createElement('submit', 'gopc', 'go postcode');
        $buttons[] =& HTML_QuickForm::createElement('text', 'search', null, array('size' => 20, 'maxlength' => 255));
        $buttons[] =& HTML_QuickForm::createElement('submit', 'gos', 'search');
        $form->addElement('hidden', 'page', $this->id);
        $form->addGroup($buttons, 'stuff', null, '&nbsp', false);

        // Conditional parts: 
        if ($rep_id) {
            // Edit representative
            $repinfo = dadem_get_representative_info($rep_id);
            dadem_check_error($repinfo);
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

            $form->addElement('header', '', 'Edit Representative');
            $form->addElement('static', 'note1', null, "Edit only
            the values which you need to.  Blank to return to default.");
            $form->addElement('text', 'name', "Full name:", array('size' => 60));
            $form->addElement('text', 'party', "Political party:", array('size' => 60));
            $form->addElement('static', 'note2', null, "Make sure you
            update contact method when you change email or fax
            numbers.");
            $form->addElement('select', 'method', "Contact method to use:", 
                    array('either' => 'Fax or Email', 'fax' => 'Fax only', 
                        'email' => 'Email only', 'shame' => 'Shame!  Doesn\'t want contacting',
                        'unknown' => 'We don\'t know contact details'
                        ));
            $form->addElement('text', 'email', "Email address:", array('size' => 60));
            $form->addElement('text', 'fax', "Fax number:", array('size' => 60));
            $form->addElement('textarea', 'note', "Note to add to log:
            (where new data was from etc.)", array('rows' => 3, 'cols' => 60));
            $form->addElement('hidden', 'pc', $pc);
            $form->addElement('hidden', 'rep_id', $rep_id);

            $finalgroup[] = &HTML_QuickForm::createElement('submit', 'done', 'Done');
            $finalgroup[] = &HTML_QuickForm::createElement('submit', 'cancel', 'Cancel');
            $form->addGroup($finalgroup, "finalgroup", "",' ', false);
    
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
        } else if ($pc) {
            // Postcode search
            $voting_areas = mapit_get_voting_areas($pc);
            mapit_check_error($voting_areas);
            $areas = array_values($voting_areas);
            $areas_info = mapit_get_voting_areas_info($areas);
            mapit_check_error($areas_info);
            foreach ($areas_info as $area=>$area_info) {
                $va_id = $area;

                // One voting area
                $reps = dadem_get_representatives($va_id);
                dadem_check_error($reps);
                $reps = array_values($reps);
                $html = "<p><b>" . $area_info['name'] . " (" .  $area_info['type_name'] . ") </b></p>"; 
                $html .= $this->render_reps($self_link, $reps);
            }
            $form->addElement('static', 'bytype', null, $html);
        } else if ($search) {
            // Search reps
            $reps = dadem_search_representatives($search);
            dadem_check_error($reps);
            $html = $this->render_reps($self_link, $reps);
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
        $form = new HTML_QuickForm('adminRepsForm', 'get', $self_link);
   }
}


?>
