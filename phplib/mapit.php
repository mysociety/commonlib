<?php
/* 
 * mapit.php:
 * Client interface for MaPit
 *
 * Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
 * WWW: http://www.mysociety.org
 *
 */

require_once('rabx.php');

/* mapit_get_error R
 * Return FALSE if R indicates success, or an error string otherwise. */
function mapit_get_error($e) {
    if (!rabx_is_error($e))
        return FALSE;
    else
        return $e->text;
}

/* mapit_check_error R
 * If R indicates failure, displays error message and stops procesing. */
function mapit_check_error($data) {
    if ($error_message = mapit_get_error($data))
        err($error_message);
}

define('MAPIT_BAD_POSTCODE', 2001);        /*    String is not in the correct format for a postcode.  */
define('MAPIT_POSTCODE_NOT_FOUND', 2002);        /*    The postcode was not found in the database.  */
define('MAPIT_AREA_NOT_FOUND', 2003);        /*    The area ID refers to a non-existent area.  */

$mapit_ch = null;
function call($url, $params, $opts = array(), $errors = array()) {
    global $mapit_ch;
    if (is_null($mapit_ch)) {
        $mapit_ch = curl_init();
        curl_setopt($mapit_ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($mapit_ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
        curl_setopt($mapit_ch, CURLOPT_USERAGENT, 'PHP MaPit client');
    }
    if (is_array($params)) $params = join(',', $params);
    if (strpos($url, '/'))
        list ($urlp, $after) = explode('/', $url, 2);
    else
        list ($urlp, $after) = array($url, '');
    if ($params) $urlp .= '/' . rawurlencode($params);
    if ($after) $urlp .= "/$after";
    if (strlen(OPTION_MAPIT_URL . $urlp) > 1024) {
        $opts['URL'] = $params;
    }
    $qs = '';
    foreach ($opts as $k => $v) {
        if (!$v) continue;
        if (is_array($v)) $v = join(',', $v);
        $qs .= $qs ? ';' : '';
        $qs .= rawurlencode($k) . '=' . rawurlencode($v);
    }
    if (strlen(OPTION_MAPIT_URL . $urlp) > 1024) {
        curl_setopt($mapit_ch, CURLOPT_URL, OPTION_MAPIT_URL . $url);
        curl_setopt($mapit_ch, CURLOPT_POST, 1);
        curl_setopt($mapit_ch, CURLOPT_POSTFIELDS, $qs);
    } elseif (strlen(OPTION_MAPIT_URL . "$urlp?$qs") > 1024) {
        curl_setopt($mapit_ch, CURLOPT_URL, OPTION_MAPIT_URL . $urlp);
        curl_setopt($mapit_ch, CURLOPT_POST, 1);
        curl_setopt($mapit_ch, CURLOPT_POSTFIELDS, $qs);
    } else {
        if ($qs) $urlp .= "?$qs";
        curl_setopt($mapit_ch, CURLOPT_URL, OPTION_MAPIT_URL . $urlp);
        curl_setopt($mapit_ch, CURLOPT_HTTPGET, 1);
        curl_setopt($mapit_ch, CURLOPT_HTTPHEADER, array("Pragma: "));
    }

    if (!($r = curl_exec($mapit_ch))) {
        return rabx_error(RABX_ERROR_TRANSPORT, curl_error($mapit_ch) . " calling $url");
    }
    $C = curl_getinfo($mapit_ch, CURLINFO_HTTP_CODE);

    $out = json_decode($r, true);

    if ($C == 404 && $errors['404']) {
        return rabx_error($errors['404'], $out['error']);
    } elseif ($C == 400 && $errors['400']) {
        return rabx_error($errors['400'], $out['error']);
    } elseif ($C != 200) {
        return rabx_error(RABX_ERROR_TRANSPORT, "HTTP error $C calling $url");
    } else {
        return $out;
    }
}

function mapit_get_voting_areas($postcode, $generation = null) {
    return call('get_voting_areas', $postcode, array( 'generation' => $generation),
        array( 400 => MAPIT_BAD_POSTCODE, 404 => MAPIT_POSTCODE_NOT_FOUND )
    );
}

function mapit_get_voting_area_info($area) {
    return call('get_voting_area_info', $area, array(), array( 404 => MAPIT_AREA_NOT_FOUND ));
}

function mapit_get_voting_areas_info($ary) {
    return call('get_voting_areas_info', $ary, array(), array( 404 => MAPIT_AREA_NOT_FOUND ));
}

function mapit_get_voting_area_by_name($name, $type = null, $min_generation = null) {
    return call('get_voting_area_by_name', $name, array( 'type' => $type, 'min_generation' => $min_generation ) );
}

function mapit_get_areas_by_type($type, $min_generation = null) {
    return call('get_areas_by_type', $type, array( 'min_generation' => $min_generation ) );
}

function mapit_get_example_postcode($id) {
    return call('get_example_postcode', $id);
}

function mapit_get_voting_area_children($id) {
    return call('get_voting_area_children', $id);
}

function mapit_get_location($postcode, $partial = array()) {
    return call('get_location', $postcode, $partial,
        array( 400 => MAPIT_BAD_POSTCODE, 404 => MAPIT_POSTCODE_NOT_FOUND )
    );
}

