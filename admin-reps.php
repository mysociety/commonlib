<?php
/*
 * Representatives admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-reps.php,v 1.19 2005-02-21 11:37:32 francis Exp $
 * 
 */

require_once "dadem.php";
require_once "mapit.php";

class ADMIN_PAGE_REPS {
    function ADMIN_PAGE_REPS () {
        $this->id = "reps";
        $this->navname= "Representative Data";
    }

    function render_reps($self_link, $reps) {
        $html = "";
        $info = dadem_get_representatives_info($reps);
        dadem_check_error($info);

        foreach ($reps as $rep) {
            $repinfo = $info[$rep];
            if ($repinfo['deleted']) {
                $html .= "<i>deleted</i> ";
            } else if (array_key_exists('edited', $repinfo) and $repinfo['edited']) {
                $html .= "<i>edited</i> ";
            }
            if (array_key_exists('type', $repinfo))
                $html .= $repinfo['type'] . " ";
            else
                $html .= $repinfo['area_type'] . " ";
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
        // Make new rep in this voting area
        $new_in_va_id = get_http_var('new_in_va_id');
        // Postcode
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
            if (!$rep_id) {
                // Making a new representative, put in type and id
                $newdata['area_id'] = $new_in_va_id;
                $vainfo = mapit_get_voting_area_info($new_in_va_id);
                mapit_check_error($vainfo);
                $newdata['area_type'] = $vainfo['type'];
            }
            $result = dadem_admin_edit_representative($rep_id, $newdata, http_auth_user(), get_http_var('note'));
            dadem_check_error($result);
            $rep_id = $result;
            $new_in_va_id = null;
            print "<p><i>Successfully updated representative ". htmlspecialchars($rep_id) . "</i></i>";
            $rep_id = null;
        }
        if (get_http_var('delete') != "") {
            $result = dadem_admin_edit_representative($rep_id, null, http_auth_user(), get_http_var('note'));
            dadem_check_error($result);
            print "<p><i>Successfully deleted representative ". htmlspecialchars($rep_id) . "</i></i>";
            $rep_id = null;
        }
        if (get_http_var('ucclose') != "") {
            $result = dadem_admin_done_user_correction(get_http_var('ucid'));
            dadem_check_error($result);
            print "<p><i>Successfully closed correction ". htmlspecialchars(get_http_var('ucid')) . "</i></i>";
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
        if ($rep_id or $new_in_va_id) {
            $form = new HTML_QuickForm('adminRepsEditForm', 'get', $self_link);
            $form->addElement('hidden', 'page', $this->id);

            // Edit representative
            if ($rep_id) {
                $repinfo = dadem_get_representative_info($rep_id);
                dadem_check_error($repinfo);
            }
            $va_id = $rep_id ? $repinfo['voting_area'] : $new_in_va_id;
            $vainfo = mapit_get_voting_area_info($va_id);
            mapit_check_error($vainfo);
            if ($vainfo['parent_area_id']) {
                $parentinfo = mapit_get_voting_area_info($vainfo['parent_area_id']);
                mapit_check_error($parentinfo);
            } else 
                $parentinfo = null;
            $rephistory = $rep_id ? dadem_get_representative_history($rep_id) : array();
            dadem_check_error($rephistory);
            // Reverse postcode lookup
            if (!$pc) {
                $pc = mapit_get_example_postcode($va_id);
                mapit_check_error($pc);
                $form->addElement('static', 'note1', null, "Example postcode for testing: " . htmlentities($pc));
            }

            if ($rep_id) {
                $form->setDefaults(
                    array('name' => $repinfo['name'],
                    'party' => $repinfo['party'],
                    'method' => $repinfo['method'],
                    'email' => $repinfo['email'],
                    'fax' => $repinfo['fax']));
            }
    
            // Councillor types are not edited here, but in match.cgi interface
            global $va_council_child_types;
            $editable_here = true;
            if (in_array($vainfo['type'], $va_council_child_types)) {
                $editable_here = false;
            }
            $readonly = $editable_here ? null : "readonly";

            if ($rep_id) 
                $form->addElement('header', '', 'Edit Representative');
            else
                $form->addElement('header', '', 'New Representative');
            if ($rep_id and $editable_here) {
                $form->addElement('static', 'note1', null, "
                Edit only the values which you need to.  Blank to return to default.
                If a representative has changed delete them and make a new one.
                Do not just edit their values, as this would ruin our reponsiveness
                stats.");
            }
            $form->addElement('static', 'office', 'Office:',
                htmlspecialchars($vainfo['rep_name']) . " for " . 
                htmlspecialchars($vainfo['name']) . " " . htmlspecialchars($vainfo['type_name']) . 
                ($parentinfo ? " in " . 
                htmlspecialchars($parentinfo['name']) . " " . htmlspecialchars($parentinfo['type_name']) : "" ));
            $form->addElement('text', 'name', "Full name:", array('size' => 60, $readonly => 1));
            $form->addElement('text', 'party', "Party:", array('size' => 60, $readonly => 1));
            $form->addElement('static', 'note2', null, "Make sure you
            update contact method when you change email or fax
            numbers.");
            $form->addElement('select', 'method', "Contact method:", 
                    array(
                        'either' => 'Fax or Email', 'fax' => 'Fax only', 
                        'email' => 'Email only',
                        'shame' => "Shame! Doesn't want contacting",
                        'via' => 'Contact via electoral body (e.g. Democratic Services)',
                        'unknown' => "We don't know contact details"
                    ),
                    array($readonly => 1));
            $form->addElement('text', 'email', "Email:", array('size' => 60, $readonly => 1));
            $form->addElement('text', 'fax', "Fax:", array('size' => 60, $readonly => 1));
            $form->addElement('textarea', 'note', "Notes for log:", array('rows' => 3, 'cols' => 60, $readonly => 1));
            $form->addElement('hidden', 'pc', $pc);
            if ($rep_id) 
                $form->addElement('hidden', 'rep_id', $rep_id);
            else
                $form->addElement('hidden', 'new_in_va_id', $new_in_va_id);

            if ($editable_here) {
                $finalgroup[] = &HTML_QuickForm::createElement('submit', 'done', 'Done');
                $finalgroup[] = &HTML_QuickForm::createElement('submit', 'cancel', 'Cancel');
                if ($rep_id) {
                    $finalgroup[] = &HTML_QuickForm::createElement('static', 'newlink', null,
                        "<a href=\"$self_link&pc=" .  urlencode(get_http_var('pc')). "&new_in_va_id=" . 
                        $va_id .  "\">" . 
                        "Make new " . 
                        htmlspecialchars($vainfo['name']) . " rep". 
                        "</a> \n");
                    if ($repinfo['deleted']) {
                        $finalgroup[] = &HTML_QuickForm::createElement('static', 'staticspacer', null, '&nbsp; Deleted rep, no longer in office, just click done to undelete');
                    } else {
                        $finalgroup[] = &HTML_QuickForm::createElement('static', 'staticspacer', null, '&nbsp; No longer in office? --->');
                        $finalgroup[] = &HTML_QuickForm::createElement('submit', 'delete', 'Delete');
                    }
                }
                $form->addGroup($finalgroup, "finalgroup", "",' ', false);
            } else {
                $form->addElement('static', 'note3', null, 
                    '<a href="'.OPTION_ADMIN_SERVICES_CGI.'match.cgi?page=councilinfo;area_id='
                    . $vainfo['parent_area_id'] . '">To edit Councillors please use the match.cgi interface</a>'.
                    '<br><a href="'.$self_link.'&ds_va_id='
                    . $vainfo['parent_area_id'] . '">... or edit Democratic Services for this council</a>');
            }
    
            $form->addElement('header', '', 'Historical Changes (each
                relative to imported data)');
            $html = "<table border=1>";
            $html .= "<th>Order</th><th>Date</th><th>Editor</th><th>Note</th>
                <th>Name</th> <th>Party</th> <th>Method</th> <th>Email</th>
                <th>Fax</th><th>Deleted</th>";

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
                $html .= "<td>" . $row['deleted'] . "</td>\n";
                $html .= "</tr>";
            }
            $html .= "</table>";
            $form->addElement('static', 'bytype', null, $html);
            admin_render_form($form);
        } else if ($search) {
            $form = new HTML_QuickForm('adminRepsSearchResults', 'get', $self_link);

            // Search reps
            $reps = dadem_search_representatives($search);
            dadem_check_error($reps);
            $html = $this->render_reps($self_link, $reps);
            $form->addElement('static', 'bytype', null, $html);

            admin_render_form($form);
        } else if ($pc) {
            $form = new HTML_QuickForm('adminRepsSearchResults', 'get', $self_link);
            
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

            admin_render_form($form);
        } else {
            // General Statistics

            // Bad contacts
            $form = new HTML_QuickForm('adminRepsBad', 'post', $self_link);
            $badcontacts = dadem_get_bad_contacts();
            dadem_check_error($badcontacts);
            $form->addElement('header', '', 'Bad Contacts ' . count($badcontacts));
            $html = $this->render_reps($self_link, $badcontacts);
            $form->addElement('static', 'badcontacts', null, $html);
            admin_render_form($form);

            // User submitted corrections
            $form = new HTML_QuickForm('adminRepsCorrectionsHeader', 'post', $self_link);
            $corrections = dadem_get_user_corrections();
            dadem_check_error($corrections);
            $form->addElement('header', '', 'User Submitted Corrections ' . count($corrections));
            admin_render_form($form);
            // Get all the data for areas and their parents in as few call as possible
            $vaids = array();
            foreach ($corrections as $correction) {
                array_push($vaids, $correction['voting_area_id']);
            }
            $info1 = mapit_get_voting_areas_info($vaids);
            mapit_check_error($info1);
            $vaids = array();
            foreach ($info1 as $key=>$value) {
                array_push($vaids, $value['parent_area_id']);
            }
            $info2 = mapit_get_voting_areas_info($vaids);
            
            foreach ($corrections as $correction) {
                $form = new HTML_QuickForm('adminRepsCorrections', 'post', $self_link);
                $html = "";
                $rep = $correction['representative_id'];

                $html .= "<p>";
                $html .= strftime('%Y-%m-%d %H:%M:%S', $correction['whenentered']) . " ";
                if ($correction['user_email'])
                    $html .= " by " . htmlspecialchars($correction['user_email']);
                $html .= "<br>";
                if ($correction['voting_area_id']) {
                    $wardinfo = $info1[$correction['voting_area_id']];
                    $vaid = $wardinfo['parent_area_id'];
                    $vainfo = $info2[$vaid];
                    // TODO: Make this councilinfo, and give a valid r= return URL
                    $html .= '<a href="'.OPTION_ADMIN_SERVICES_CGI.'match.cgi?page=councilinfo;area_id='
                        . $vaid . '&r=' . '">' . 
                        htmlspecialchars($vainfo['name']) . "</a>, ";
                    $html .= htmlspecialchars($wardinfo['name']);
                    $html .= "<br>";
                }
                $html .= $correction['alteration'] . " ";

                if ($rep) {
                    $repinfo = dadem_get_representative_info($rep);
                    dadem_check_error($repinfo);

                    $html .= "<a href=\"$self_link&pc=" .  urlencode(get_http_var('pc')). "&rep_id=" . $rep .  "\">" . htmlspecialchars($repinfo['name']) . " (". htmlspecialchars($repinfo['party']) . ")</a> \n";
                    if ($correction['alteration'] != "delete") {
                        $html .= " to ";
                    }
                }
                if ($correction['alteration'] != "delete") {
                    $html .= htmlspecialchars($correction['name']) .  " (" . htmlspecialchars($correction['party']) . ")";
                }
                if ($correction['user_notes'])
                    $html .= "<br>Notes: " . htmlspecialchars($correction['user_notes']);

                $usercorr = array();
                $usercorr[] =& HTML_QuickForm::createElement('static', 'usercorrections', null, $html);
                // You can't do this with element type "hidden" as it only allows one value in a
                // page for variable named ucid.  So once again I go to raw HTML.  Remind me not
                // to use HTML_QuickForm again...
                $usercorr[] =& HTML_QuickForm::createElement('html', 
                    '<input name="ucid" type="hidden" value="'. $correction['user_correction_id'] . '" />');
                $usercorr[] =& HTML_QuickForm::createElement('submit', 'ucclose', 'hide (done)');
                $form->addGroup($usercorr, 'stuff', null, '&nbsp', false);
                admin_render_form($form);
            }

            $form = new HTML_QuickForm('adminRepsStats', 'post', $self_link);

            // MaPit
            $form->addElement('header', '', 'Postcode/Area Statistics (MaPit)');
            $mapitstats = mapit_admin_get_stats();
            mapit_check_error($mapitstats);
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

            admin_render_form($form);
        }
   }
}


?>
