<?php
/*
 * error.php:
 * Error handling apparatus for PHP programs.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: error.php,v 1.14 2007-08-15 12:51:01 matthew Exp $
 * 
 */

# Tip of the Day:  This code grabs a backtrace into a string, and 
# writes it to the Apache error log.  print_r can only do this
# in PHP 4.3.0 and above.
#       error_log(print_r(debug_backtrace(), TRUE));

/* Make sure register globals is turned off */
if (ini_get("register_globals")) {
    print "Turn off register_globals in php.ini";
    exit;
}

/*
 * PHP error handling is, you will not be surprised to hear, completely
 * amateurish. It doesn't have exceptions and it doesn't have nonlocal jumps
 * either, so we can't emulate exceptions. (Exception: PHP 5 has exceptions,
 * but we're not using that.)
 * 
 * There is the notion of an "error handler", which is a function called when
 * an "error" occurs (generated either by PHP or raised by code via the
 * trigger_error function. Note that trigger_error and the error handler
 * functions are not a control flow mechanism -- the default behaviour is for
 * the error handler to do its stuff, and then return control to the calling
 * code. Observe that this is exactly like handling the error, except that it
 * lacks the key concepts of "error" and "handling".
 *
 * We adapt the error handling apparatus as follows:
 * 
 *   - Install a default error handler which calls an error logging handler,
 *     and an error display handler, and then aborts.
 *
 *   - The default error logging handler takes steps to dump the error in
 *     the proper server error log (PHP makes this quite hard, as you will
 *     see below); the default error display handler does nothing.
 * 
 *   - The user may override either handler using our own functions.
 */


/*
 * Implementation.
 */

/* err ERROR
 * Report the given ERROR and abort. */
function err($str, $num = E_USER_ERROR) {
    /* We can't just call trigger_error, because that will always report this
     * function as the location where the error occured. So use debug_backtrace
     * to construct the relevant information. */
    $a = debug_backtrace(); /* now $a[1], if present, is the caller */
    $i = 0;
    if (array_key_exists(1, $a))
        $i = 1;
    if (!array_key_exists('file', $a[$i])) $a[$i]['file'] = '(unknown file)';
    if (!array_key_exists('line', $a[$i])) $a[$i]['line'] = '(unknown line)';
    err_global_handler($num, $str, $a[$i]['file'], $a[$i]['line'],
                        /* XXX We can't obtain the calling context AFAIK. */
                        null);
    exit(1); /* NOTREACHED */
}

/* err_log_webserver NUMBER STRING FILE LINE CONTEXT
 * Log the error with the given parameters, trying to arrange that it reach the
 * appropriate web server error log. */
function err_log_webserver($num, $str, $file, $line, $context) {
#print "<pre>";
#print_r($context);
#error_log(print_r($context, TRUE));
#print "</pre>";

    /* Apache (and perhaps other webservers) logs errors preceded by a tag
     * giving the time and "severity" of the error. The time is in the format
     * "[%a %b %d %H:%M:%S %Y]", and the "severity" is one of "[error]",
     * "[warning]" or "[notice]". */

    $prefix = '';
    
    /* Time. */
/*
    $prefix .= strftime('[%a %b %d %H:%M:%S %Y]') . " ";
*/
    /* Severity. */
/*
    if ($num & (E_WARNING | E_CORE_WARNING | E_USER_WARNING))
        $prefix .= '[warning]';
    else if ($num & (E_NOTICE | E_USER_NOTICE))
        $prefix .= '[notice]';
    else
        $prefix .= '[error]';
    $prefix .= ' ';
*/

    /* File/line of error. */
    $prefix .= "$file:$line: ";

    foreach (explode("\n", $str) as $line) {
        /* We have to use error_log here because printing to php://stderr is
         * broken in both FastCGI and the mod_php implementations. See
         * http://bugs.php.net/bug.php?id=31472 for the FCGI case. */
        error_log($prefix . $line);
    }
}

$err_handler_log = 'err_log_webserver';
$err_handler_display = null;
$err_handling_error = false; // true if currently handling an error

/* err_global_handler NUMBER STRING FILE LINE CONTEXT
 * Handler for all categories of errors. */
function err_global_handler($num, $str, $file, $line, $context) {
    global $err_handler_log;
    global $err_handler_display;
    global $err_handling_error;
    $err_handling_error = true;

    // PHP5.1RC* a bit overzealous about strict errors, even if not set to display:
    if (version_compare(phpversion(), "5.0") >= 0 && $num == E_STRICT) { return; }

    if (isset($err_handler_log) && $num != E_USER_NOTICE)
        $err_handler_log($num, $str, $file, $line, $context);
    if (isset($err_handler_display))
        $err_handler_display($num, $str, $file, $line, $context);
    else
        $err_handler_log($num, "no error display handler set", $file, $line, $context);
    exit(1);
}

/* err_set_handler_log FUNCTION
 * Set the log handler to FUNCTION (a string naming a function). It should take
 * arguments as for the set_error_handler. FUNCTION may be null to turn off
 * error logging. */
function err_set_handler_log($func) {
    global $err_handler_log;
    if (isset($func) && !function_exists($func))
        err("err_set_log_handler: called with name of nonexistent function '$func'");
    $err_handler_log = $func;
}

/* err_set_handler_display FUNCTION
 * Set the display handler to FUNCTION (a string naming a function). It should
 * take arguments as for the set_error_handler. FUNCTION may be null to turn
 * off error logging. */
function err_set_handler_display($func) {
    global $err_handler_display;
    if (isset($func) && !function_exists($func))
        err("err_set_display_handler: called with name of nonexistent function '$func'");
    $err_handler_display = $func;
}

/* 
 * Now, make some brute-force changes to our configuration, so that
 * error-handling behaves sanely.
 */

/* Never display errors to user. */
ini_set('display_errors', 'Off');
ini_set('display_startup_errors', 'Off');

/* Log errors; our error handler will still be called for errors raised by our
 * code, but this means that we still get to find out about PHP internal errors
 * such as compilation problems. */
ini_set('log_errors', 'On');

/* But do not place any arbitrary limits on the length of errors logged by
 * error_log. */
ini_set('log_errors_max_len', '0');

/* And try, as hard as possible, to make logged errors go to the server's
 * error log. */
ini_set('error_log', null);

/* Trap all errors. */
ini_set('ignore_repeated_errors', 'Off');

/* Don't put HTML tags in error messages. */
ini_set('html_errors', 'Off');

/* Ask for reporting of *all* errors. */
error_reporting(E_ALL);

/* Finally, set our error handler to be the default. Most classes of errors
 * cannot be trapped by a user error-handler, of course. */
set_error_handler('err_global_handler');

?>
