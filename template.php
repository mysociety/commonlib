<?php
/*
 * template.php:
 * Basic web templating.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: template.php,v 1.9 2006-05-18 15:16:07 matthew Exp $
 * 
 */

require_once('error.php');

$template_style_dir = null;
$real_template_name = null;

/* template_set_style STYLE [ADDITIONAL]
 * Sets or adds (if ADDITIONAL is true) the given STYLE for templates in
 * use. STYLE should be the name of a directory where template HTML files
 * are stored, relative to the caller's current directory. This function
 * must be called before any other template functions. Later additional
 * calls to this function are given preference in template searching. */
function template_set_style($style_dir, $additional = false) {
    global $template_style_dir;
    /* This is just a convenience check -- obviously the directory could be
     * removed or replaced with a file before the files within it are read. */
    if (!file_exists($style_dir) || !is_dir($style_dir))
        err("style directory \"$style_dir\" doesn't exist or isn't a directory");
    if ($additional)
        array_unshift($template_style_dir, $style_dir);
    else
        $template_style_dir = array($style_dir);
}

/* template_draw TEMPLATE [VALUES]
 * Call the given TEMPLATE (name of an HTML or PHP file in the templates
 * directory or directories, without the ".html" or ".php" suffix). If
 * set, the given VALUES will be assigned to the variable $values when
 * the template is executing. A template is expected to write output to
 * standard output. */
function template_draw($template_name, $values = null) {
    global $template_style_dir, $real_template_name;
    if (!isset($template_style_dir))
        err("no template style directory set");

    /* Convenience check, again. */
    $found = false;
    foreach ($template_style_dir as $dir) {
        if (file_exists("$dir/$template_name.html")) {
            $real_template_name = $template_name;
            require "$dir/$template_name.html";
            $found = true;
            break;
        } elseif (file_exists("$dir/$template_name.php")) {
            require "$dir/$template_name.php";
            $found = true;
            break;
        } elseif (file_exists("$dir/$template_name.xml")) {
            require "$dir/$template_name.xml";
            $found = true;
            break;
        }
    }
    if (!$found) {
    	header('HTTP/1.0 404 Not Found');
        err("template file for \"$template_name\" does not exist");
    }
}

/* template_string TEMPLATE [VALUES]
 * As for template_draw, but any output of the given TEMPLATE will be captured
 * using the output buffering mechanism and returned. */
function template_string($template_name, $values = null) {
    global $template_style_dir;
    if (!isset($template_style_dir))
        err("no template style directory set");

    ob_start();
    template_draw($template_name, $values);
    $ret = ob_get_contents();
    ob_end_clean();
    return $ret;
}

/* template_show_error MESSAGE
 * Equivalent to calling,
 *      template_draw("error-general", array(error_message => MESSAGE))
 * then exiting, except that if no template style directory is set, prints
 * the message to standard output rather than exiting. */
function template_show_error($message) {
    global $template_style_dir;
    if (!isset($template_style_dir) || !file_exists(end($template_style_dir) . '/error-general.html'))
        print $message;
    else
        /* Not safe. */
        template_draw("error-general", array("error_message" => $message));
    exit(1);
}


?>
