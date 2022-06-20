<?php
/*
 * phpcli.php:
 * To be included in all PHP CLI scripts, to sort out constants,
 * read command line arguments, and things
 *
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: matthew@mysociety.org. WWW: http://www.mysociety.org/
 *
 * $Id: phpcli.php,v 1.6 2006-07-24 00:42:09 dademcron Exp $
 *
 */

# from http://www.sitepoint.com/print/php-command-line-1 adapted for FCGI
if (php_sapi_name() == 'cgi' || php_sapi_name() == 'cgi-fcgi') {
    @ob_end_flush();
    ob_implicit_flush(TRUE);
    set_time_limit(0);
    ini_set('track_errors', TRUE);
    ini_set('html_errors', FALSE);
    define('STDIN', fopen('php://stdin', 'r'));
    define('STDOUT', fopen('php://stdout', 'w'));
    define('STDERR', fopen('php://stderr', 'w'));
    register_shutdown_function(function() {
        fclose(STDIN); fclose(STDOUT); fclose(STDERR); return true;
    });
}

require_once 'Console/Getopt.php';
define('SUCCESS', 0);
define('PROBLEM', 1);
define('NO_ARGS', 10);
define('INVALID_OPTION', 11);
$args = Console_Getopt::readPHPArgv();
if (PEAR::isError($args)) {
    fwrite(STDERR, $args->getMessage()."\n");
    exit(NO_ARGS);
}
$options = Console_Getopt::getOpt($args,$short_opts,$long_opts); 
if (PEAR::isError($options)) {
    fwrite(STDERR, $options->getMessage()."\n");
    exit(INVALID_OPTION);
}

require_once dirname(__FILE__) . '/error.php';

/* error display to standard error */
function err_display_stderr($num, $str, $file, $line, $context) {
    $stderr = fopen('php://stderr', 'w');
    fwrite($stderr,"$file:$line\n$str\n");
    fclose($stderr); 
}
err_set_handler_display('err_display_stderr');
err_set_handler_log(null);

?>
