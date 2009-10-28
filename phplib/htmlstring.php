<?php
/*
 * htmlstring.php:
 * Experimental - not really ready yet.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: htmlstring.php,v 1.3 2006-06-19 16:40:31 francis Exp $
 * 
 */

/* Example usage:

 print_html(p(format("hello is %0.2f foi"), 8.12345));
 print_html(p(html(format("foo < bar %d foo %s ha"), 7, html("hello > foo"))));
 print_html(ul(li("First"), li("Second"), li("The first % of life")));

 TODO: 

 - How to handle character types? Links cause similar problem.
 print_html(p('This is a really long sentence with <strong>emphasis on good bits</strong>, and less on others.'));
 - format is a bit too generic a name. Chris suggests F(), but ugly.
 - PledgeBank already uses obvious names like p() and so on.
   Maybe put all the functions in an (effectively singleton) object like $q in CGI.pm?
 - Let <li> say take an array and wrap elements separately in <li> and join together
*/

// Prints an HTMLString, can construct one wth format parameters
function print_html() {
    $args = func_get_args();
    $hs = new HTMLString($args);
    print $hs->html;
}

// Constructs HTMLString, with format parameters passed through
function html($text) {
    $args = func_get_args();
    return new HTMLString($args);
}

// Constructs HTMLString wrapped in tag opening and closing
function htmlstring_tag($tag, $args) {
    $hs = new HTMLString($args);
    $hs->html = "<$tag>" . $hs->html . "</$tag>";
    return $hs;
}

// Standard HTML tags
function p() { $args = func_get_args(); return htmlstring_tag("p", $args); }
function h1() { $args = func_get_args(); return htmlstring_tag("h1", $args); }
function h2() { $args = func_get_args(); return htmlstring_tag("h2", $args); }
function h3() { $args = func_get_args(); return htmlstring_tag("h3", $args); }
function h4() { $args = func_get_args(); return htmlstring_tag("h4", $args); }
function strong() { $args = func_get_args(); return htmlstring_tag("strong", $args); }
function em() { $args = func_get_args(); return htmlstring_tag("em", $args); }
function dt() { $args = func_get_args(); return htmlstring_tag("dt", $args); }
function dd() { $args = func_get_args(); return htmlstring_tag("dd", $args); }
function ul() { $args = func_get_args(); return htmlstring_tag("ul", $args); }
function ol() { $args = func_get_args(); return htmlstring_tag("ol", $args); }
function li() { $args = func_get_args(); return htmlstring_tag("li", $args); }

// Indicates a format specifier
function format($text) {
    return new HTMLString_FormatSpecifier($text);
}

// Type for a string containing HTML
class HTMLString {
    var $html;
    function HTMLString($args = array()) {
        if (is_a($args[0], "HTMLString_FormatSpecifier")) {
            $format = array_shift($args);
            // sprintf constructor
            $new_args = array();
            foreach ($args as $arg) {
                if (gettype($arg) == "string") 
                    $arg = htmlspecialchars($arg);    
                elseif (gettype($arg) == "integer") 
                    { } // do nothing
                elseif (gettype($arg) == "double") 
                    { } // do nothing
                elseif (is_a($arg, "HTMLString"))
                    $arg = $arg->html;
                else
                    trigger_error("HTMLString formatting does not know type " . gettype($arg), E_USER_ERROR);
                $new_args[] = $arg;
            }
            $this->html = vsprintf(htmlspecialchars($format->text), $new_args);
        } else {
            // appending constructor
            // (appends all parametrs, can be strings or HTMLStrings)
            foreach ($args as $arg) {
                if (is_a($arg, "HTMLString"))
                    $this->html .= $arg->html;
                elseif (gettype($arg) == "string")
                    $this->html .= htmlspecialchars($arg);
                else
                    trigger_error("Appending constructor takes HTMLString and string only, not " . gettype($arg), E_USER_ERROR);
            }
        }
    }

    function append($a) {
        if (gettype($a) == "string") 
            $a = new HTMLString($a);
        if (!is_a($a, "HTMLString"))
            trigger_error("HTMLString.append expects an HTMLString, not " . get_class($a), E_USER_ERROR);
        $this->html .= $a->html;
    }
}

// Type to indicate a printf style format specifier
class HTMLString_FormatSpecifier {
    var $text;
    function HTMLString_FormatSpecifier($a) {
        $this->text = $a;
    }
}

