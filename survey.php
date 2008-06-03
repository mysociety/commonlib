<?php
/*
 * survey.php:
 * Client code for the demographic surveys - call from sites which show the survey.
 * 
 * Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: survey.php,v 1.1 2008-06-03 19:05:32 francis Exp $
 * 
 */

function survey_sign_email_address($email) {
    // Encode the email address to make the user code, so that anyone just with access to the survey database
    // can't work out what the email is. We don't have a salt, as we want to be able to test uniqueness.
    $user_code = sha1($email . "-" . OPTION_SURVEY_SECRET); 
    // And sign it to authorise it
    $auth_signature = auth_sign_with_shared_secret($user_code, OPTION_SURVEY_SECRET); 

    return array($user_code, $auth_signature);
}

function survey_check_if_already_done($user_code, $auth_signature) {
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
    curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    curl_setopt($ch, CURLOPT_USERAGENT, 'PHP survey client, version $Id: survey.php,v 1.1 2008-06-03 19:05:32 francis Exp $');
    curl_setopt($ch, CURLOPT_URL, OPTION_SURVEY_URL);
    curl_setopt($ch, CURLOPT_POST, 1);
    curl_setopt($ch, CURLOPT_POSTFIELDS, "querydone=1&user_code=" . urlencode($user_code) . "&auth_signature=" . urlencode($auth_signature));

    $r = curl_exec($ch);
    if ($r === FALSE)
        err(curl_error($ch) . " curling " . OPTION_SURVEY_URL);
    $errcode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    if ($errcode != 200)
        err("Error $errcode curling " . OPTION_SURVEY_URL);

    curl_close($ch);
    
    return $r ? true : false;
}


