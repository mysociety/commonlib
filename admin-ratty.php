<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-ratty.php,v 1.4 2004-11-11 18:15:14 francis Exp $
 * 
 */

class ADMIN_PAGE_RATTY {
    function ADMIN_PAGE_RATTY () {
        $this->id = "ratty";
        $this->name = "Ratty";
        $this->navname = "Ratty the Rate Limiter";
    }

    function display($self_link) {
        $action = get_http_var('action');
        if ($action == "")
            $action = "editrule";

        if ($action == "editrule") {
            $rule = get_http_var('rule');
            $ruledata = array();
            if ($rule = "") {
               $ruledata['note'] = ""; 
            }
            $conditiondata = array(
                array('condition' => 'S'),
                array('condition' => 'E'),
                array('condition' => 'R'),
                array('condition' => 'D'),
            );
    
            $form = new HTML_QuickForm('adminRattyRuleForm', 'get', $self_link);
            $form->setDefaults($ruledata);

            $form->addElement('header', '', $rule = "" ? 'New Rate-Limiting Rule' : 'Edit Rate-Limiting Rule');
            $form->addElement('text', 'sequence', "Rule evaluation position:", array('size' => 20, 'maxlength' => 20));
            $form->addElement('textarea', 'note', "Description of rule:", array('rows' => 3, 'cols' => 40));
            $form->addElement('text', 'requests', "Limit to this many hits:", array('size' => 20, 'maxlength' => 20));
            $form->addElement('text', 'interval', "Every this many seconds:", array('size' => 20, 'maxlength' => 20));
    
            // Get list of fields from ratty
            $fieldarray = ratty_admin_available_fields();
            $fields = array();
            foreach ($fieldarray as $row) {
                $fields[$row[0]] = $row[0];
            }

            // Grouped elements
            $ix = 0;
            foreach ($conditiondata as $condition) {
                $ix++;
                $condgroup[0] = &HTML_QuickForm::createElement('select', "field$ix", 'Field:', $fields);
                
                if ($condition['condition'] == 'S') {
                    $condgroup[1] = &HTML_QuickForm::createElement('select', "condition$ix", "Operator:", array('S'=>'exactly equal to'));
                    $desc = 'Count hits separately for each:';
                }
                else if ($condition['condition'] == 'S') {
                    $condgroup[1] = &HTML_QuickForm::createElement('select', "condition$ix", "Operator:", array('D'=>'exactly equal to'));
                    $desc = 'Limit number of distinct values of:';
                }
                else {
                    $condgroup[1] = &HTML_QuickForm::createElement('select', "condition$ix", "Operator:", 
                        array('E'=>'exactly equals', 'R'=>'matches regexp', 'I'=>'matches IP mask'));
                    $desc = 'Applies only when:';
                }
                $condgroup[2] = &HTML_QuickForm::createElement('text', "value$x", "Value:", array('size' => 15));
                $form->addGroup($condgroup, "condition$ix", $desc,' ');
            }

            $form->addElement('hidden', 'page', $this->id);
            $form->addElement('submit', 'go', 'Submit');
        }

        admin_render_form($form);
    }
}

?>
