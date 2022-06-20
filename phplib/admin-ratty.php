<?php
/*
 * admin-ratty.php:
 * Administration pages for rate limiter. This object is used as part of our
 * admin interface, see admin_page_display() in phplib/abuse.php for how to
 * include it.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-ratty.php,v 1.43 2010-01-19 18:28:14 louise Exp $
 * 
 */

require_once dirname(__FILE__) . "/ratty.php";

require_once dirname(__FILE__) . "/HTML/QuickForm.php";
require_once dirname(__FILE__) . "/HTML/QuickForm/Rule.php";
require_once dirname(__FILE__) . "/HTML/QuickForm/Renderer/Default.php";

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
        $this->navname = "$what Rules";

        $this->scope = $scope;
        $this->scope_title = $what;
        $this->scope_description = $description;
        $this->scope_messageblurb = $messageblurb;
    }

    function display($self_link) {
        $action = get_http_var('action');
        if ($action == "")
            $action = "listrules";
        if ($action <> "editrule" && $action <> "listrules") {
            print "<p>Unknown ratty admin display action '$action'</p>";
        }

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
                    /* Parse normal/inverted condition */
                    $c = get_http_var("condition$ix");
                    $condition['invert'] = (substr($c, 0, 1) == '+') ? 0 : 1;
                    $condition['condition'] = substr($c, 1, 1);
                    $condition['field'] = get_http_var("field$ix");
                    $condition['value'] = get_http_var("value$ix");
                    array_push($conditiondata, $condition);
                }
            }

            if (get_http_var('newfilter') != "") {
                array_push($conditiondata, array('condition' => 'E', 'invert' => 0));
            }
            if (get_http_var('newsingle') != "") {
                array_push($conditiondata, array("condition" => 'S', 'invert' => 0));
            }
            if (get_http_var('newdistinct') != "") {
                array_push($conditiondata, array("condition" => 'D', 'invert' => 0));
            }

            $form = new HTML_QuickForm('adminRattyRuleForm', 'post', $self_link);
            # Resplice conditions with numbers for form
            $cform = array();

            /* Copy condition data into form, fixing up normal/inverted rules
             * as we go. */
            for ($ix = 1; $ix <= count($conditiondata); ++$ix) {
                foreach ($conditiondata[$ix - 1] as $key => $value) {
                    if ($key == 'condition')
                        $cform["condition$ix"] = ($conditiondata[$ix - 1]['invert'] ? '-' : '+') . $value;
                    else if ($key != 'invert')
                        $cform[$key . $ix] = $value;
                }
            }
            $form->setDefaults(array_merge($ruledata, $cform));

            if (array_key_exists('rule_id', $ruledata))
                $form->addElement('hidden', 'rule_id', $ruledata['rule_id']);
            $form->addElement('hidden', 'page', $this->id);
            $form->addElement('hidden', 'action', $action);

            $form->addElement('header', '', $rule = "" ? 'New Rate-Limiting Rule' : 'Edit Rate-Limiting Rule');

            $titlegroup = array();
            $titlegroup[] = $form->createElement('text', 'note', null, array('size' => 40));
            $titlegroup[] = $form->createElement('static', null, null, "<b>Eval position:</b>");
            $titlegroup[] = $form->createElement('text', 'sequence', "Rule evaluation position:", array('size' => 5, 'maxlength' => 10));
            $form->addRule('sequence', 'Rule position must be numeric', 'numeric', null, 'server');
            $form->addGroup($titlegroup, "titlegroup", "Title of rule:", null, false);

            $limitgroup = array();
            $limitgroup[] = $form->createElement('text', 'requests', null, array('size' => 5, 'maxlength' => 10));
            $limitgroup[] = $form->createElement('static', null, null, "<b> hits every </b>");
            $limitgroup[] = $form->createElement('text', 'interval', null, array('size' => 5, 'maxlength' => 10));
            $limitgroup[] = $form->createElement('static', null, null, "<b> seconds</b>. Leave blank/zero to block completely.");
            $form->addGroup($limitgroup, "limitgroup", "Limit rate to:", null, false);

            $form->addElement('textarea', 'message', "Action when rule fires:<br>(for help see below)", array('rows' => 3, 'cols' => 60));
            $form->addRule('requests', 'Hit count must be numeric', 'numeric', null, 'server');
            $form->addRule('interval', 'Time period must be numeric', 'numeric', null, 'server');
            $form->addRule('note', 'Description is required', 'required', null, 'server');
            $form->addRule('requests', 'Requests is required', 'required', null, 'server');
            $form->addRule('interval', 'Interval is required', 'required', null, 'server');

            $form->addElement('header', '', 'Conditions for Rule');
    
            // Get list of fields from ratty
            $fieldarray = ratty_admin_available_fields($this->scope);
            sort($fieldarray);
            $fields = array();
            foreach ($fieldarray as $row) {
                list($field_name, $field_description, $field_examples) = $row;
                $fields[$field_name] = $field_name;
                if (count($field_examples) > 0) {
                    // Get field as an example
                    $example = $field_examples[0];
                    // Search for one that isn't empty
                    if (!$example and count($field_examples) > 1) {
                        $example = $field_examples[1];
                    }
                    $fields[$field_name] .= " (e.g. " .  trim_characters($example, 0, 20) . ")";
                }
            }

            // Grouped elements
            $ix = 0;
            foreach ($conditiondata as $condition) {
                $ix++;
                $condgroup = array();
                $condgroup[0] = $form->createElement('select', "field$ix", null, $fields);

                if ($condition['condition'] == 'S') {
                    $condgroup[1] = $form->createElement('hidden', "condition$ix", 'S');
                    $desc = 'Limit hits separately for each:';
                } else if ($condition['condition'] == 'D') {
                    $condgroup[1] = $form->createElement('hidden', "condition$ix", 'D');
                    $desc = 'Limit number of distinct values of:';
                } else {
                    $condgroup[1] = $form->createElement('select', "condition$ix", null, 
                            array(
                                '+E' => 'exactly equals',
                                '-E' => 'does not equal',
                                '+R' => 'matches regexp',
                                '-R' => 'does not match regexp',
                                '+T' => 'roughly matches text',
                                '-T' => 'does not roughly match text',
                                '+I' => 'matches IP mask',
                                '-I' => 'does not match IP mask',
                                '+>' => 'is greater than',
                                '+<' => 'is smaller than',
                                '+P' => 'is present',
                                '-P' => 'is not present',
                            )
                        );
                    $desc = 'Applies only when:';
                    $condgroup[2] = $form->createElement('text', "value$ix", null, array('size' => 15));
                }
                array_push($condgroup, $form->createElement('submit', "delete$ix", 'Del'));
                $form->addGroup($condgroup, "c$ix", $desc, null, false);
                $form->addRule("c$ix", 'Please use a valid regular expression', 'callback', 'check_condition_regexp');

            }

            $buttongroup[0] = $form->createElement('submit', 'newfilter', 'Apply only when...');
            $buttongroup[1] = $form->createElement('submit', 'newsingle', 'Limit hits separately for each...');
            $buttongroup[2] = $form->createElement('submit', 'newdistinct', 'Limit number of distinct values of...');
            $form->addGroup($buttongroup, "buttongroup", "Add new rule condition:",' <br> ', false);

            $form->addElement('header', '', 'Submit Changes');
            $finalgroup = array();
            $finalgroup[] = $form->createElement('submit', 'done', 'Done');
            $finalgroup[] = $form->createElement('submit', 'cancel', 'Cancel');
            $finalgroup[] = $form->createElement('submit', 'deleterule', 'Delete Rule');
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

                print "<h2>Help &mdash; What goes in the action box?</h2>";
                print $this->scope_messageblurb; 
                print "<h2>Help &mdash; What do all the fields mean?</h2>";
                print "<p>";
                foreach ($fieldarray as $row) {
                    list($field_name, $field_description, $field_examples) = $row;
                    print "<b>$field_name:</b> $field_description. ";
                    print "e.g. " . implode(", ", array_map(
                    function($a) { return "'".trim_characters($a, 0, 50)."'"; }, $field_examples));
                    print "<br>";
                }
                print "</p>";
            }
        }
        if ($action == "listrules") {
            $rules = ratty_admin_get_rules($this->scope);
            print <<<EOF
<h2>$this->scope_title Rules</h2> 
<p>$this->scope_description</p>
<table border="1" width="100%">
    <tr>
        <th>Order</th>
        <th>Description</th>
        <th>Hit limit</th>
        <th>Action</th>
        <th>Matches in<br>time period[1]</th>
EOF;
            if ($this->scope == "fyr-abuse") {
                print "<th>Messages</th>";
            }
            print <<<EOF
    </tr>
EOF;
            $c = 1;
            foreach ($rules as $rule) {
                if ($rule['note'] == "") 
                    $rule['note'] = "&lt;unnamed&gt;";
                print '<tr'.($c==1?' class="v"':'').'>';
                print "<td>" . $rule['sequence'] . "</td>";
                print "<td><a href=\"$self_link&amp;action=editrule&amp;rule_id=" .     /* XXX use url_new... */
                    $rule['id'] . "\">" . $rule['note'] . "</a></td>";
                if ($rule['requests'] == 0 && $rule['interval'] == 0) {
                    print "<td>blocked</td>";
                } else {
                    print "<td>" . $rule['requests'] . " hits / " . $rule['interval'] . " " . make_plural($rule['interval'], 'sec'). "</td>";
                }
                print "<td>" . trim_characters($rule['message'], 0, 40) . "</td>";
                print "<td>" . $rule['hits'] . "</td>";
                if ($this->scope == "fyr-abuse") {
                    print "<td><a href=\"?page=fyrqueue&amp;view=logsearch&amp;query=" .     /* XXX use url_new... */
                    urlencode(" rule #" . $rule['id'] . " ") . "\">View</a></td>";
                }
                print "</tr>";

                $c = 1 - $c;
            }
?>
</table>
<?php
            print "<p><a href=\"$self_link&amp;action=editrule\">New rule</a>";
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
<p>[1] <b>Matches</b> has slightly different meanings for different rules types.
For straightforward filter rules, it means the number of hits in the last 
time period (roughly - it actually means the number of hits in the time period
up until the last hit).  "Time period" here is the number of seconds in the
"Hit limit" column.  For more complicated "Limit hits separately..." and "Limit
number of distinct..." rules, matches is a count of how many times just the 
simple filter conditions were met, not how many times the rule actually triggered.
Note that if the time period is zero, you don't get very useful results.
</p>
<?php
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
