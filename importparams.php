<?php
/*
 * importparams.php:
 * Check and import values from HTTP variables.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: importparams.php,v 1.10 2006-07-15 20:50:51 matthew Exp $
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
 * none is supplied in the query. Valid values for variables are written into
 * variables named $q_PARAMETER, where PARAMETER is the name of the parameter;
 * an HTML entities-encoded copy is also written into $q_h_PARAMETER. Parameter
 * values will also be written into $q_unchecked_PARAMETER and
 * $q_h_unchecked_PARAMETER, whether or not they are valid.  Import returns
 * null on success or an array mapping named PARAMETERs to error strings if any
 * of the parameters didn't match.
 * If PARAMETER is an array, the first entry is the PARAMETER name for the above,
 * the second is a boolean stating whether user input changes can be made (for
 * Esperanto only currently)
 */
function importparams() {
    global $lang;
    $i = 0;
    $errors = array();
    $valid = array();
    for ($i = 0; $i < func_num_args(); ++$i) {
        $pp = func_get_arg($i);
        if (!is_array($pp) || count($pp) < 2 || count($pp) > 4)
            err("each SPEC must be an array of 2, 3 or 4 elements");

        $allow_changes = false;
        $name = $pp[0];
        if (is_array($name)) {
            $allow_changes = $name[1];
            $name = $name[0];
        }

        if (!is_string($name))
            err("PARAMETER should be a string");

        /* Obtain parameter value. */
        if (array_key_exists($name, $_POST)) {
            $val = $_POST[$name];
            if (!is_array($val)) $val = trim($val);
        } elseif (array_key_exists($name, $_GET)) {
            $val = $_GET[$name];
            if (!is_array($val)) $val = trim($val);
        } else
            $val = null;
        if (!is_null($val) && $allow_changes && $lang == 'eo')
            $val = input_esperanto($val);
            
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
            if (preg_match($check, '') === false)
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

        eval("global \$q_$name;");
        eval("global \$q_h_$name;");
        if (!is_null($error))
            $errors[$name] = $error;
        else {
            eval("\$q_$name = \$val;");
            eval("\$q_h_$name = htmlspecialchars(\$val);");
        }
 
        eval("global \$q_unchecked_$name;");
        eval("global \$q_unchecked_h_$name;");
        if (is_null($val))
            $val = '';
        eval("\$q_unchecked_$name = \$val;");
        eval("\$q_unchecked_h_$name = htmlspecialchars(\$val);");
    }

    if (count($errors) > 0)
        return $errors;
    else
        return null;
}

function importparams_validate_postcode($pc) {
    $pc = canonicalise_postcode($pc);
    if (validate_postcode($pc)) {
        return null;
    } else {
        return "Please enter a valid postcode, such as OX1 3DR";
    }
}

function importparams_validate_email($email) {
    if (validate_email($email)) {
        return null;
    } else {
        return "Please enter a valid email address";
    }
}

?>
