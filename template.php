<?php
/*
 * template.php:
 * Basic templating.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: template.php,v 1.5 2005-01-11 16:09:10 chris Exp $
 * 
 */

require_once('error.php');

$template_style_dir = null;

/* template_set_style STYLE
 * Set the given STYLE for templates in use. STYLE should be the name of a
 * directory where template HTML files are stored, relative to the caller's
 * current directory. This function must be called before any other template
 * functions. */
function template_set_style($style_dir) {
    global $template_style_dir;
    /* This is just a convenience check -- obviously the directory could be
     * removed or replaced with a file before the files within it are read. */
    if (!file_exists($style_dir) || !is_dir($style_dir))
        err("style directory \"$style_dir\" doesn't exist or isn't a directory");
    $template_style_dir = $style_dir;
}

/* template_draw TEMPLATE [VALUES]
 * Call the given TEMPLATE (name of an HTML file in the templates directory,
 * without the ".html" suffix). If set, the given VALUES will be assigned to
 * the variable $values when the template is executing. A template is expected
 * to write output to standard output. */
function template_draw($template_name, $values = null) {
    global $template_style_dir;
    if (!isset($template_style_dir))
        err("no template style directory set");

    /* Convenience check, again. */
    if (file_exists("$template_style_dir/$template_name.html"))
        require "$template_style_dir/$template_name.html";
    else
        err("template file for \"$template_name\" does not exist");
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
    if (!isset($template_style_dir) || !file_exists("$template_style_dir/error-general.html"))
        print $message;
    else
        /* Not safe. */
        template_draw("error-general", array("error_message" => $message));
    exit(1);
}


?>
