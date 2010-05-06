<?php
/*
 * cli.php:
 * A few functions for scripts run from the command-line.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: cli.php,v 1.5 2007-04-16 13:34:06 francis Exp $
 * 
 */

$cli_program_name = preg_replace('#^.*/#', '', $argv[0]);
$cli_is_verbose = false;
$cli_show_warnings = true;

/* verbose STRING
 * If $cli_is_verbose is true, then print STRING to standard error, followed
 * by a \n. */
function verbose($str) {
    global $cli_is_verbose, $cli_program_name;
    if (!$cli_is_verbose) return;
    fwrite(STDERR, "$cli_program_name: $str\n");
}

/* warning STRING
 * Print STRING to standard error, followed by a \n. */
function warning($str) {
    global $cli_program_name, $cli_show_warnings;
    if (!$cli_show_warnings) return;
    fwrite(STDERR, "$cli_program_name: $str\n");
}

/* error STRING
 * Print STRING to standard error, prefixed "ERROR", followed by a \n. */
function error($str) {
    global $cli_program_name;
    fwrite(STDERR, "$cli_program_name: ERROR: $str\n");
    /* XXX abort at this point? */
}

?>
