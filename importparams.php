<?php
/*
 * importparams.php:
 * Check and import values from HTTP variables.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: importparams.php,v 1.1 2005-03-03 15:20:33 chris Exp $
 * 
 */

require_once("error.php");
require_once("utility.php");

/* importparams SPEC ...
 * Each argument to this function is a array SPEC containing the elements
 *      PARAMETER CHECK [ERROR] [DEFAULT]
 * The function imports a set of named PARAMETERs from the HTTP query into PHP
 * variables, checking them for validity. CHECK should be either a callback
 * which is passed the actual value of the parameter, and should return null if
 * the value is valid or a descriptive error message if it is not; or a string,
 * which will be interpreted as a PCRE regular expression as in preg_match, in
 * which case ERROR should be the text of the error to use if the value does
 * not match the regular expression. If specified, DEFAULT is a value to use if
 * none is supplied in the query. If there are no errors, valid values for
 * variables are written into variables named $q_PARAMETER, where PARAMETER is
 * the name of the parameter; an HTML entities-encoded version of the data is
 * also written into $q_h_PARAMETER. Import returns null on success or an array
 * mapping named PARAMETERs to error strings if any of the parameters didn't
 * match. */
function importparams() {
    $i = 0;
    $errors = array();
    $valid = array();
    for ($i = 0; $i < func_num_args(); ++$i) {
        $pp = func_get_arg($i++);
        if (!is_array($pp) || count($pp) < 2 || count($pp) > 4)
            err("each SPEC must be an array of 2, 3 or 4 elements");
        $name = $pp[0];
        if (!is_string($name))
            err("PARAMETER should be a string");

        /* Obtain parameter value. */
        if (array_key_exists($name, $_POST))
            $val = $_POST[$name];
        else if (array_key_exists($name, $_GET))
            $val = $_GET[$name];
        else
            $val = null;
            
        $check = $pp[1];
        $error = null;
        $have_default = false;
        if (is_callable($check)) {
            if (count($pp) == 4)
                err("If CHECK is a function it should only be followed by an optional DEFAULT");
            else if (count($pp) == 3) {
                $default = $pp[2];
                $have_default = true;
            }
        } else if (is_string($check)) {
            if (preg_match($check, '') == false)
                err("If CHECK is a string, it must be a valid PCRE regular expression, not '$check'");
            else if (count($pp) < 3 || !is_string($pp[2]))
                err("If CHECK is a regular expression, it must be followed by an ERROR string");
            if (count($pp) == 4) {
                $default = $pp[3];
                $have_default = true;
            }
        } else {
            err("CHECK should be callable or a string");
        }

        if (is_null($val)) {
            if ($have_default)
                $val = $default;
            else
                $error = "Missing parameter '$name'";
        } else {
            if (is_callable($check))
                $error = $check($val);
            else if (is_string($check) && 0 == preg_match($check, $val))
                $error = $pp[2];
        }

        if (!is_null($error))
            $errors[$name] = $error;
        else
            $valid[$name] = $val;
    }

    if (count($errors) > 0)
        return $errors;

    foreach ($valid as $name => $val) {
        eval("our \$${q}_$name;");
        eval("our \$${q}_h_$name;");
        eval("\$${q}_$name = \$val;");
        eval("\$${q}_h_$name = htmlspecialchars(\$val);");
    }
}

?>
