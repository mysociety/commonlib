<?php
/*
 * ratty.php:
 * Basic templating.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: template.php,v 1.2 2004-11-16 15:08:43 francis Exp $
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
        print "Please set template style_dir.";
        exit;
    }
    
    include $template_style_dir . "/" . $template_name . ".html";
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

function template_show_error() {
    global $fyr_error_message;
    template_draw("error-general", array("error_message" => $fyr_error_message));
    exit;
}


?>
