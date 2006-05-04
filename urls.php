<?php
/*
 * urls.php:
 * URL functions.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: urls.php,v 1.3 2006-05-04 12:19:43 chris Exp $
 * 
 */

/* url_invoked 
 * Return the URL under which the script was invoked. The port is specified
 * only if it is not the default (i.e. 80 for HTTP and 443 for HTTPS). */
function url_invoked() {
    $url = 'http';
    $ssl = FALSE;
    if (array_key_exists('SSL', $_SERVER)) {
        $url .= "s";
        $ssl = TRUE;
    }
    $url .= "://" . $_SERVER['HTTP_HOST'];

    if ((!$ssl && $_SERVER['SERVER_PORT'] != 80)
        || ($ssl && $_SERVER['SERVER_PORT'] != 443))
        $url .= ":" . $_SERVER['SERVER_PORT'];

    $url .= preg_replace("/\?.*/", "", $_SERVER['REQUEST_URI']);

    return $url;
}

/* url_new PAGE RETAIN [PARAM VALUE ...]
 * Return a new URL for PAGE with added parameters. If RETAIN is true, then all
 * of the parameters with which the page was originally invoked will be
 * retained in the original URL; additionally, any PARAM VALUE pairs will be
 * added. If a PARAM is specified it overrides any retained parameter value; if
 * a VALUE is null, any retained PARAM is removed. If a VALUE is an array,
 * multiple URL parameters will be added. If PAGE is null the URL under which
 * this page was invoked is used. */
function url_new($page, $retain) {
    if (!isset($page))
        $page = invoked_url();
    $url = "$page";

    $params = array();
    if ($retain)
        /* GET takes priority over POST. This isn't the usual behaviour but is
         * consistent with other bits of the code (see fyr/phplib/forms.php) */
        $params = array_merge($_POST, $_GET);

    if (func_num_args() > 2) {
        if ((func_num_args() % 2) != 0)
            die("call to url_new with odd number of arguments");
        for ($i = 2; $i < func_num_args(); $i += 2) {
            $k = func_get_arg($i);
            $v = func_get_arg($i + 1);
            if (array_key_exists($k, $params))
                unset($params[$k]);
            $params[func_get_arg($i)] = func_get_arg($i + 1);
        }
    }
    
    if (count($params) > 0) {
        $keyvalpairs = array();
        foreach ($params as $key => $val) {
            if (is_array($val)) {
                for ($i = 0; $i < count($val); ++$i)
                    $keyvalpairs[] = urlencode($key) . '=' . urlencode($val[$i]);
            } elseif ($val)
                $keyvalpairs[] = urlencode($key) . '=' . urlencode($val);
        }
        $url .= '?' . join('&', $keyvalpairs);
    }

    return $url;
}

?>
