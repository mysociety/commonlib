<?php
/*
 * admin-ratty.php:
 * Administration pages for rate limiter.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-ratty.php,v 1.26 2005-01-13 11:29:26 francis Exp $
 * 
 */

require_once "ratty.php";

class ADMIN_PAGE_RATTY {
    /* ADMIN_PAGE_RATTY SCOPE WHAT DESCRIPTION MESSAGEBLURB
     * Create a new Ratty administration interface object. SCOPE is the Ratty
     * scope which will be edited; WHAT is a concise description of what this
     * scope applies to (e.g. "WriteToThem website"; DESCRIPTION is a longer
     * description (which may include HTML), and MESSAGEBLURB (which may also
     * include HTML) describes how the caller will interpret values of the
     * message field in rate-limiting rules (e.g., "HTML fragment to be
     * displayed to user when rule fires."). The contents of MESSAGEBLURB will
     * be displayed inside a <div>. */
    function ADMIN_PAGE_RATTY($scope, $what, $description, $messageblurb) {
        $this->id = "ratty-" . $scope;
        $this->name = "Ratty";
        $this->navname = "Rate Limit - $what";

        $this->scope = $scope;
        $this->scope_title = $what;
        $this->scope_description = $description;
        $this->scope_messageblurb = $messageblurb;
    }

    function display($self_link) {
        //print "<pre>"; print_r($_POST); print "</pre>";

        $action = get_http_var('action');
        if ($action == "")
            $action = "listrules";

        if ($action == "editrule") {
            if (!array_key_exists('sequence', $_POST)) {
                if (get_http_var('rule_id') == "") {
                    $ruledata = array();
                    $conditiondata = array();
                } else {
                    $ruledata = ratty_admin_get_rule($this->scope, get_http_var('rule_id'));
                    $ruledata['rule_id'] = get_http_var('rule_id');
                    $conditiondata = ratty_admin_get_conditions($this->scope, get_http_var('rule_id'));
                }
            } else {
                // Load data from form
                $ruledata = array();
                $ruledata['rule_id'] = intval(get_http_var('rule_id'));
                $ruledata['requests'] = intval(get_http_var('requests')); 
                $ruledata['interval'] = intval(get_http_var('interval'));
                $ruledata['sequence'] = intval(get_http_var('sequence'));
                $ruledata['note'] = get_http_var('note'); 
                $ruledata['message'] = get_http_var('message'); 
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
            $form->addElement('text', 'note', "Title of rule:", array('size' => 60, 'maxlength' => 80));

            $limitgroup = array();
            $limitgroup[] = &HTML_QuickForm::createElement('text', 'requests', null, array('size' => 5, 'maxlength' => 10));
            $limitgroup[] = &HTML_QuickForm::createElement('static', null, null, "<b> hits every </b>");
            $limitgroup[] = &HTML_QuickForm::createElement('text', 'interval', null, array('size' => 5, 'maxlength' => 10));
            $limitgroup[] = &HTML_QuickForm::createElement('static', null, null, "<b> seconds</b>. Leave blank to block completely.");
            $form->addGroup($limitgroup, "limitgroup", "Limit rate to:", null, false);

            $form->addElement('textarea', 'message', "Action when rule fires:", array('rows' => 3, 'cols' => 60));
            $form->addElement('static', '', '', "<div><b>What goes 
            in the action box?</b> " . $this->scope_messageblurb . "</div>");
            $form->addElement('text', 'sequence', "Rule evaluation position:", array('size' => 10, 'maxlength' => 20));
            $form->addRule('sequence', 'Rule position must be numeric', 'numeric', null, 'server');
            $form->addRule('requests', 'Hit count must be numeric', 'numeric', null, 'server');
            $form->addRule('interval', 'Time period must be numeric', 'numeric', null, 'server');
            $form->addRule('note', 'Description is required', 'required', null, 'server');
            $form->addRule('requests', 'Requests is required', 'required', null, 'server');
            $form->addRule('interval', 'Interval is required', 'required', null, 'server');

            $form->addElement('header', '', 'Conditions for Rule');
    
            // Get list of fields from ratty
            $fieldarray = ratty_admin_available_fields($this->scope);
            $fields = array();
            foreach ($fieldarray as $row) {
                $fields[$row[0]] = $row[0] . " (e.g. " .  trim_characters($row[1], 0, 30) . ")";
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
                            array(
                                'E' => 'exactly equals',
                                'R' => 'matches regexp',
                                'I' => 'matches IP mask',
                                '>' => 'is greater than',
                                '<' => 'is smaller than'
                            )
                        );
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

            if (array_key_exists('rule_id', $ruledata))
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
                    $new_rule_id = ratty_admin_update_rule($this->scope, $ruledata, $conditiondata);
                    $action = "listrules";
                }
            } else if (get_http_var('cancel') != "") {
                $action = "listrules";
            } else if (get_http_var('deleterule') != "") {
                if ($ruledata['rule_id'] != "") {
                    ratty_admin_delete_rule($this->scope, $ruledata['rule_id']);
                }
                $action = "listrules";
            }
            
            if ($action == "editrule") {
                admin_render_form($form);
            }
        }
        if ($action == "listrules") {
            $rules = ratty_admin_get_rules($this->scope);
            print <<<EOF
<h2>$this->scope_title Rules</h2> 
<p>$this->scope_description</h1></p>
<table border="1" width="100%">
    <tr>
        <th>Eval Order</th>
        <th>Description</th>
        <th>Hit limit</th>
        <th>Matches</th>
    </tr>
EOF;
            $c = 1;
            foreach ($rules as $rule) {
                if ($rule['note'] == "") 
                    $rule['note'] = "&lt;unnamed&gt;";
                print '<tr'.($c==1?' class="v"':'').'>';
                print "<td>" . $rule['sequence'] . "</td>";
                print "<td><a href=\"$self_link&action=editrule&rule_id=" .     /* XXX use new_url... */
                    $rule['id'] . "\">" . $rule['note'] . "</a></td>";
                print "<td>" . $rule['requests'] . " hits / " . $rule['interval'] . " " . make_plural($rule['interval'], 'sec'). "</td>";
                print "<td>" . $rule['hits'] . "</td>";
                print "</tr>";

                $c = 1 - $c;
            }
?>
</table>
<?
            print "<p><a href=\"$self_link&action=editrule\">New rule</a>";
?>
<h2>Help &mdash; how do these rules work?</h2>
<p>
Each rule has a hit rate limit, which limits the number of times a
request or operation is permitted to, at most, the maximum number of
hits in any given specific time period.  (You can set the hit limit to 0
to completely block access.)
</p>
<p>
Conditions within the rule let you specify when it applies.  For example, you
can apply the rule only for certain URLs, IP addresses or postcodes. You can
also make the rule count limits separately for each distinct value of
something, for example, IP addresses, or alternatively limit the number of
distinct representatives which can be viewed per unit time.
</p>
<p>
Rules are applied in order. Each request is tested against each rule in turn
until one matches, in which case the request is denied; or until there are no
more rules, in which case the request is permitted.
</p>
<?
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
