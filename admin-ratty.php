<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-ratty.php,v 1.12 2004-11-15 18:35:24 francis Exp $
 * 
 */

class ADMIN_PAGE_RATTY {
    function ADMIN_PAGE_RATTY () {
        $this->id = "ratty";
        $this->name = "Ratty";
        $this->navname = "Ratty the Rate Limiter";
    }

    function display($self_link) {
        #print "<pre>"; print_r($_POST); print "</pre>";

        $action = get_http_var('action');
        if ($action == "")
            $action = "listrules";

        if ($action == "editrule") {
            if (!array_key_exists('sequence', $_POST)) {
                if (get_http_var('rule_id') == "") {
                    $ruledata = array();
                    $conditiondata = array();
                } else {
                    $ruledata = ratty_admin_get_rule(get_http_var('rule_id'));
                    $ruledata['rule_id'] = get_http_var('rule_id');
                    $conditiondata = ratty_admin_get_conditions(get_http_var('rule_id'));
                }
            } else {
                // Load data from form
                $ruledata = array();
                $ruledata['rule_id'] = intval(get_http_var('rule_id'));
                $ruledata['requests'] = intval(get_http_var('requests')); 
                $ruledata['interval'] = intval(get_http_var('interval'));
                $ruledata['sequence'] = intval(get_http_var('sequence'));
                $ruledata['note'] = get_http_var('note'); 
                $conditiondata = array();
                for ($ix = 1; get_http_var("condition$ix") != ""; $ix++) {
                    if (get_http_var("delete$ix") != "")
                        continue;
                    $condition = array();
                    $condition['condition'] = get_http_var("condition$ix");
                    $condition['field'] = get_http_var("field$ix");
                    $condition['value'] = get_http_var("value$ix");
                    array_push($conditiondata, $condition);
                }
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
            # Resplice conditions with numbers for form
            $cform = array();
            $ix = 0;
            foreach ($conditiondata as $dummy => $cond) {
                $ix++;
                foreach ($cond as $key => $value) {
                    $cform[$key . $ix] = $value;
                }
            }
            $form->setDefaults(array_merge($ruledata, $cform));

            $form->addElement('header', '', $rule = "" ? 'New Rate-Limiting Rule' : 'Edit Rate-Limiting Rule');
            $form->addElement('text', 'sequence', "Rule evaluation position:", array('size' => 10, 'maxlength' => 20));
            $form->addElement('text', 'note', "Description of rule:", array('size' => 60, 'maxlength' => 80));
            $form->addElement('text', 'requests', "Limit to this many hits:", array('size' => 10, 'maxlength' => 20));
            $form->addElement('text', 'interval', "Every this many seconds:", array('size' => 10, 'maxlength' => 20));
            $form->addRule('sequence', 'Rule position must be numeric', 'numeric', null, 'server');
            $form->addRule('requests', 'Hit count must be numeric', 'numeric', null, 'server');
            $form->addRule('interval', 'Time period must be numeric', 'numeric', null, 'server');
            $form->addRule('note', 'Description is required', 'required', null, 'server');
            $form->addRule('requests', 'Requests is required', 'required', null, 'server');
            $form->addRule('interval', 'Interval is required', 'required', null, 'server');

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
                $form->addRule("c$ix", 'Please use a valid regular expression', 'callback', 'check_condition_regexp');

            }

            $buttongroup[0] = &HTML_QuickForm::createElement('submit', 'newfilter', 'Apply only when...');
            $buttongroup[1] = &HTML_QuickForm::createElement('submit', 'newsingle', 'Limit hits separately for each...');
            $buttongroup[2] = &HTML_QuickForm::createElement('submit', 'newdistinct', 'Limit number of distinct values of...');
            $form->addGroup($buttongroup, "buttongroup", "Add new rule condition:",' <br> ', false);

            $form->addElement('hidden', 'rule_id', $ruledata['rule_id']);
            $form->addElement('hidden', 'page', $this->id);
            $form->addElement('hidden', 'action', $action);
            $form->addElement('header', '', 'Submit Changes');
            $finalgroup[] = &HTML_QuickForm::createElement('submit', 'done', 'Done');
            $finalgroup[] = &HTML_QuickForm::createElement('submit', 'cancel', 'Cancel');
            $finalgroup[] = &HTML_QuickForm::createElement('submit', 'deleterule', 'Delete Rule');
            $form->addGroup($finalgroup, "finalgroup", "",' ', false);

            if (get_http_var('done') != "") {
                if ($form->validate()) {
                    $new_rule_id = ratty_admin_update_rule($ruledata, $conditiondata);
                    $action = "listrules";
                }
            } else if (get_http_var('cancel') != "") {
                $action = "listrules";
            } else if (get_http_var('deleterule') != "") {
                if ($ruledata['rule_id'] != "") {
                    ratty_admin_delete_rule($ruledata['rule_id']);
                }
                $action = "listrules";
            }
            
            if ($action == "editrule") {
                admin_render_form($form);
            }
        }
        if ($action == "listrules") {
            $rules = ratty_admin_get_rules();
?>
<p>Rules enforce limits on access to web pages.  Each rule has a hit rate
limit, which you can set to 0 per second to completely block access.
Conditions within the rule let you specify when it applies.  For
example, you can apply the rule only for certain URLs.  You can also
make the rule count limits separately for each distinct, for example, IP
address.  Or alternatively limit the number of distinct representatives
which can be viewed per unit time.
</p>
<table border=1
width=100%><tr><th>Position</th><th>Description</th><th>Hit
limit</th><th>Matches</th></tr>
<?
            foreach ($rules as $rule) {
                if ($rule['note'] == "") 
                    $rule['note'] = "&lt;unnamed&gt;";
                print "<tr>";
                print "<td>" . $rule['sequence'] . "</td>";
                print "<td><a href=\"$self_link&action=editrule&rule_id=" .
                    $rule['id'] . "\">" . $rule['note'] . "</a></td>";
                print "<td>" . $rule['requests'] . " hits / " . $rule['interval'] . " " . make_plural("sec", $rule['interval']). "</td>";
                print "<td>" . $rule['hits'] . "</td>";
                print "</tr>";
            }
?>
</table>
<?
            print "<p><a href=\"$self_link&action=editrule\">New rule</a>";
        }

    }
}

    function check_condition_regexp($arr) {
        $cond = "";
        $value = "";
        foreach ($arr as $k => $v) {
            if (!(strpos($k, "condition") === FALSE)) $cond = $v;
            if (!(strpos($k, "value") === FALSE)) $value = $v;
        }
        if ($cond == "R") 
            return check_is_valid_regexp($value);
// TODO: add IP mask matching
//        if ($cond == "I") 
//            return check_is_valid_ipmask($value);
        return TRUE;
    }


?>
