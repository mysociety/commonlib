<?php
/*
 * ratty.php:
 * Basic templating.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: template.php,v 1.4 2004-12-08 23:26:40 matthew Exp $
 * 
 */

$template_style_dir = null;

function template_set_style($style_dir) {
    global $template_style_dir;
    $template_style_dir = $style_dir;
}

function template_draw($template_name, $values = null) {
    global $template_style_dir;
    if ($template_style_dir == null) {
	print '<p class="error">Please set template style_dir.</p>';
	return;
    }

    if (file_exists($template_style_dir . '/' . $template_name . '.html')) {
        include $template_style_dir . '/' . $template_name . '.html';
    } else {
        print '<p class="error">Template file not found!</p>';
    }
}

function template_string($template_name, $values = null) {
    global $template_style_dir;
    if ($template_style_dir == null) {
        print "Please set template style_dir.";
        exit;
    }

    ob_start();
    include $template_style_dir . "/" . $template_name . ".html";
    $ret = ob_get_contents();
    ob_end_clean();
    return $ret;
}

function template_show_error($message) {
    global $template_style_dir;
    if ($template_style_dir == null) {
        print $message;
    } else {
        template_draw("error-general", array("error_message" => $message));
    }
    exit;
}


?>
