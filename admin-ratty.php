<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-ratty.php,v 1.5 2004-11-12 06:11:21 francis Exp $
 * 
 */

class ADMIN_PAGE_RATTY {
    function ADMIN_PAGE_RATTY () {
        $this->id = "ratty";
        $this->name = "Ratty";
        $this->navname = "Ratty the Rate Limiter";
    }

    function display($self_link) {
        //print "<pre>"; print_r($_POST); print "</pre>";

        $action = get_http_var('action');
        if ($action == "")
            $action = "editrule";

        if ($action == "editrule") {
            // Load data from form
            $ruledata = array();
            $ruledata['rule_id'] = get_http_var('rule_id'); 
            $ruledata['requests'] = get_http_var('requests'); 
            $ruledata['interval'] = get_http_var('interval'); 
            $ruledata['sequence'] = get_http_var('sequence'); 
            $ruledata['note'] = get_http_var('note'); 
            $conditiondata = array();
            for ($ix = 1; get_http_var("condition$ix") != ""; $ix++) {
                if (get_http_var("delete$ix") != "")
                    continue;
                $condition = array();
                $condition['condition'] = get_http_var("condition$ix");
                $condition['field'] = get_http_var("field$ix");
                $condition['vlaue'] = get_http_var("value$ix");
                array_push($conditiondata, $condition);
            }
            if (get_http_var('newfilter') != "") {
                array_push($conditiondata, array("condition" => 'E'));
            }
            if (get_http_var('newsingle') != "") {
                array_push($conditiondata, array("condition" => 'S'));
            }
            if (get_http_var('newdistinct') != "") {
                array_push($conditiondata, array("condition" => 'D'));
            }
    
            $form = new HTML_QuickForm('adminRattyRuleForm', 'post', $self_link);
            $form->setDefaults($ruledata);

            $form->addElement('header', '', $rule = "" ? 'New Rate-Limiting Rule' : 'Edit Rate-Limiting Rule');
            $form->addElement('text', 'sequence', "Rule evaluation position:", array('size' => 20, 'maxlength' => 20));
            $form->addElement('text', 'note', "Description of rule:", array('size' => 40, 'maxlength' => 40));
            $form->addElement('text', 'requests', "Limit to this many hits:", array('size' => 20, 'maxlength' => 20));
            $form->addElement('text', 'interval', "Every this many seconds:", array('size' => 20, 'maxlength' => 20));
            $form->addElement('header', '', 'Conditions for Rule');
    
            // Get list of fields from ratty
            $fieldarray = ratty_admin_available_fields();
            $fields = array();
            foreach ($fieldarray as $row) {
                $fields[$row[0]] = $row[0] . " (e.g. " . $row[1] . ")";
            }

            // Grouped elements
            $ix = 0;
            foreach ($conditiondata as $condition) {
                $ix++;
                $condgroup = array();
                $condgroup[0] = &HTML_QuickForm::createElement('select', "field$ix", null, $fields);
                
                if ($condition['condition'] == 'S') {
                    $condgroup[1] = &HTML_QuickForm::createElement('hidden', "condition$ix", 'S');
                    $desc = 'Limit hits separately for each:';
                }
                else if ($condition['condition'] == 'D') {
                    $condgroup[1] = &HTML_QuickForm::createElement('hidden', "condition$ix", 'D');
                    $desc = 'Limit number of distinct values of:';
                }
                else {
                    $condgroup[1] = &HTML_QuickForm::createElement('select', "condition$ix", null, 
                        array('E'=>'exactly equals', 'R'=>'matches regexp', 'I'=>'matches IP mask'));
                    $desc = 'Applies only when:';
                    $condgroup[2] = &HTML_QuickForm::createElement('text', "value$ix", null, array('size' => 15));
                }
                array_push($condgroup, HTML_QuickForm::createElement('submit', "delete$ix", 'Del'));
                $form->addGroup($condgroup, "c$ix", $desc, null, false);
            }

            $buttongroup[0] = &HTML_QuickForm::createElement('submit', 'newfilter', 'Apply only when...');
            $buttongroup[1] = &HTML_QuickForm::createElement('submit', 'newsingle', 'Limit hits separately for each...');
            $buttongroup[2] = &HTML_QuickForm::createElement('submit', 'newdistinct', 'Limit number of distinct values of...');
            $form->addGroup($buttongroup, "buttongroup", "Add new rule condition:",' <br> ', false);

            $form->addElement('hidden', 'rule_id', $this->id);
            $form->addElement('hidden', 'page', $this->id);
            $form->addElement('header', '', 'Submit Changes');
            $form->addElement('submit', 'done', 'Done');
        }

        admin_render_form($form);
    }
}

?>
