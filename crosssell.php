<?
/*
 * crosssell.php:
 * Adverts from one site to another site.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: crosssell.php,v 1.31 2008-06-24 16:41:21 francis Exp $
 * 
 */

// Config parameters site needs set to call these functions:
// OPTION_AUTH_SHARED_SECRET
// MaPit and DaDem

require_once 'auth.php';
require_once 'mapit.php';
require_once 'dadem.php';
require_once 'debug.php'; # for getmicrotime()

# Global
$crosssell_voting_areas = array();

// Choose appropriate advert and display it.
// $this_site is to stop a site advertising itself.
function crosssell_display_advert($this_site, $email = '', $name = '', $postcode = '', $adverts = array()) {

    # Always try and display a HearFromYourCouncillor Cheltenham advert if possible
    if ($this_site != 'hfyc')
        if ($ad = crosssell_display_hfyc_cheltenham_advert($email, $name, $postcode))
            return $ad;

    # If we've been sent an array of adverts, pick one at random to display
    while (count($adverts)) {
        $keys = array_keys($adverts);
        $rand = rand(0, count($adverts)-1);
        $rand = $keys[$rand];
        list ($advert_id, $advert_text) = $adverts[$rand];
        $advert_site = preg_replace('#\d+$#', '', $advert_id);
        if ($this_site == 'twfy' && $advert_site == 'twfy_alerts')
            return 'other-twfy-alert-type';
        if (call_user_func('crosssell_display_random_' . $advert_site . '_advert', $email, $name, $postcode, $advert_text, $this_site))
            return $advert_id;
        # Failed to show an advert for $advert_site, remove all other $advert_site adverts from the selection
        foreach ($adverts as $k => $advert) {
            if ($advert_site == preg_replace('#\d+$#', '', $advert[0]))
                unset($adverts[$k]);
        }
    }

    if ($this_site != 'hfymp') 
        if (crosssell_display_hfymp_advert($email, $name, $postcode))
            return 'hfymp';
/*
XXX Nothing using this fallback, and we currently want WTT fallback to
    be FMS

    if ($this_site != 'twfy') {
        if (crosssell_display_twfy_alerts_advert($this_site, $email, $postcode))
            return 'twfy';
*/
#    } else {
#        return 'other-twfy-alert-type';
    #}
    if ($this_site != 'fms') { # Always happens, as FMS uses Perl
        crosssell_display_fms_advert();
        return 'fms';
    }
    if ($this_site != 'pb') {
        crosssell_display_pb_advert();
        return 'pb';
    }
    return '';
}

/* Random adverts, text supplied by caller */

/* This advert will always display if picked */
function crosssell_display_random_fms_advert($email, $name, $postcode, $text, $this_site) {
    echo '<div id="advert_thin" style="text-align:center; font-size:150%">',
        $text, '</div>';
    return true;
}

/* This advert will always display if picked */
function crosssell_display_random_gny_advert($email, $name, $postcode, $text, $this_site) {
    echo '<div id="advert_thin">', $text, '</div>';
    return true;
}

function crosssell_display_random_hfymp_advert($email, $name, $postcode, $text, $this_site) {
    $auth_signature = crosssell_check_hfymp($email);
    if (!$auth_signature) return false;

    $text = str_replace('[button]', '
<form action="http://www.hearfromyourmp.com/" method="post">
<input type="hidden" name="name" value="' . htmlspecialchars($name) . '">
<input type="hidden" name="email" value="' . htmlspecialchars($email) . '">
<input type="hidden" name="postcode" value="' . htmlspecialchars($postcode) . '">
<input type="hidden" name="sign" value="' . htmlspecialchars($auth_signature) . '">
<h2><input style="font-size:100%" type="submit" value="', $text);
    $text = str_replace('[/button]', '"></h2></form>', $text);

    $text = str_replace('[form]', '
<form action="http://www.hearfromyourmp.com/" method="post">
<p><strong>Your email:</strong> <input type="text" name="email" value="' . htmlspecialchars($email) . '" maxlength="100" size="30">
<input type="hidden" name="name" value="' . htmlspecialchars($name) . '">
<input type="hidden" name="postcode" value="' . htmlspecialchars($postcode) . '">
<input type="hidden" name="sign" value="' . htmlspecialchars($auth_signature) . '">
<input type="submit" value="', $text);
    $text = str_replace('[/form]', '"></form>', $text);

    echo '<div style="text-align:center">', $text, '</div>';
    return true;
}

function crosssell_display_random_twfy_alerts_advert($email, $name, $postcode, $text, $this_site) {
    $check = crosssell_check_twfy($email, $postcode);
    if (is_bool($check)) return false;
    list($person_id, $auth_signature) = $check;

    $text = str_replace('[form]', '
<form action="http://www.theyworkforyou.com/alert/" method="post">
    <strong>Your email:</strong> <input type="text" name="email" value="' . $email . '" maxlength="100" size="30">
    <input type="hidden" name="pid" value="' . $person_id . '">
    <input type="hidden" name="submitted" value="true">
    <input type="hidden" name="sign" value="' . $auth_signature . '">
    <input type="hidden" name="site" value="' . $this_site . '">
    <input type="submit" value="', $text);
    $text = str_replace('[/form]', '"></form>', $text);
    $text = str_replace('[button]', '
<form action="http://www.theyworkforyou.com/alert/" method="post">
    <input type="hidden" name="email" value="' . $email . '">
    <input type="hidden" name="pid" value="' . $person_id . '">
    <input type="hidden" name="sign" value="' . $auth_signature . '">
    <input type="hidden" name="site" value="' . $this_site . '">
    <input style="font-size:150%" type="submit" value="', $text);
    $text = str_replace('[/button]', '"></p>', $text);

    echo '<div id="advert_thin" style="text-align:center">', $text, '</div>';
    return true;
}

/* Okay, now the static adverts, not being shown at random */

function crosssell_display_hfymp_advert($email, $name, $postcode) {
    $auth_signature = crosssell_check_hfymp($email);
    if (!$auth_signature) return false;

?>
<form action="http://www.hearfromyourmp.com/" method="post">
<input type="hidden" name="name" value="<?=htmlspecialchars($name)?>">
<input type="hidden" name="email" value="<?=htmlspecialchars($email)?>">
<input type="hidden" name="postcode" value="<?=htmlspecialchars($postcode)?>">
<input type="hidden" name="sign" value="<?=htmlspecialchars($auth_signature)?>">
<h2 style="padding: 1em; font-size: 200%" align="center">
Meanwhile...<br>
<input style="font-size:100%" type="submit" value="Start a long term relationship"><br> with your MP
</h2>
<?
    return true;
}

function crosssell_display_hfyc_cheltenham_advert($email, $name, $postcode) {
    if (!defined('OPTION_AUTH_SHARED_SECRET') || !$postcode)
        return false;

    global $crosssell_voting_areas;
    if (!$crosssell_voting_areas)
        $crosssell_voting_areas = mapit_get_voting_areas($postcode);
    if (!isset($crosssell_voting_areas['DIS']) || $crosssell_voting_areas['DIS'] != 2326)
        return false;

    $auth_signature = auth_sign_with_shared_secret($email, OPTION_AUTH_SHARED_SECRET);

    // See if already signed up
    $already_signed = crosssell_fetch_page('cheltenham.hearfromyourcouncillor.com', '/authed?email='.urlencode($email)."&sign=".urlencode($auth_signature));
    if ($already_signed != 'not signed') 
        return false;

    // If not, display one of two adverts
    $rand = rand(0, 1);
?>
<form action="http://cheltenham.hearfromyourcouncillor.com/" method="post">
<input type="hidden" name="name" value="<?=htmlspecialchars($name)?>">
<input type="hidden" name="email" value="<?=htmlspecialchars($email)?>">
<input type="hidden" name="postcode" value="<?=htmlspecialchars($postcode)?>">
<input type="hidden" name="sign" value="<?=htmlspecialchars($auth_signature)?>">

<div id="advert_thin">
<?

    if ($rand == 0) {
        echo "<h2>Cool! You live in Cheltenham!</h2> <p>We've got an exciting new free
        service that works exclusively for people in Cheltenham. Please sign
        up to help the charity that runs WriteToThem, and to get a sneak
        preview of our new service.</p>";
    } else {
        echo "<h2>Get to know your councillors.</h2>
        <p>Local councillors are really important, but hardly anyone knows them.
        Use our new free service to build a low-effort, long term relationship
        with your councillor.</p>";
    }
    ?>
<p align="center">
<input type="submit" value="Sign up to HearFromYourCouncillor">
</p>
</div>
</form>
<?
    return "cheltenhamhfyc$rand";
}

# XXX: Needs to say "Lord" when the WTT message was to a Lord!
function crosssell_display_twfy_alerts_advert($this_site, $email, $postcode) {
    $check = crosssell_check_twfy($email, $postcode);
    if (is_bool($check)) return false;
    list($person_id, $auth_signature) = $check;
    if ($this_site == 'hfyc') {
        $heading = 'Would you like to be emailed when your MP says something in parliament?';
    } else {
        $heading = 'Seeing as you\'re interested in your MP, would you also like to be emailed when they say something in parliament?';
    }
?>

<h2 style="border-top: solid 3px #9999ff; font-weight: normal; padding-top: 1em; font-size: 150%"><?=$heading ?></h2>
<form style="text-align: center" action="http://www.theyworkforyou.com/alert/">
    <strong>Your email:</strong> <input type="text" name="email" value="<?=$email ?>" maxlength="100" size="30">
    <input type="hidden" name="pid" value="<?=$person_id?>">            
    <input type="submit" value="Sign me up!">
    <input type="hidden" name="submitted" value="true">
    <input type="hidden" name="sign" value="<?=$auth_signature?>">
    <input type="hidden" name="site" value="<?=$this_site?>">
</form>

<p>Parliament email alerts are a free service of <a href="http://www.theyworkforyou.com">TheyWorkForYou.com</a>,
another <a href="http://www.mysociety.org">mySociety</a> site. We will treat
your data with the same diligence as we do on all our sites, and obviously you
can unsubscribe at any time.
<?  
    return true;
}

function crosssell_display_pb_advert() {
?>
<h2 style="padding: 1em; font-size: 200%" align="center">
Have you ever wanted to <a href="http://www.pledgebank.com">change the world</a> but stopped short because no-one would help?</h2>
<?
}

function crosssell_display_fms_advert() {
?>
<div id="advert_thin" style="text-align:center; font-size:150%">
<p>Got a local problem like potholes or flytipping in your street?<br><a href="http://www.fixmystreet.com/">Report it at FixMyStreet</a></p>
</div>
<?
}

/* Checking functions for sites, to see if you're already signed up or whatever */

$crosssell_check_hfymp_checked = null;
function crosssell_check_hfymp($email) {
    global $crosssell_check_hfymp_checked;
    if (!is_null($crosssell_check_hfymp_checked))
        return $crosssell_check_hfymp_checked;

    if (!defined('OPTION_AUTH_SHARED_SECRET'))
        return false;

    $auth_signature = auth_sign_with_shared_secret($email, OPTION_AUTH_SHARED_SECRET);

    // See if already signed up
    $already_signed = crosssell_fetch_page('www.hearfromyourmp.com', '/authed?email='.urlencode($email).'&sign='.urlencode($auth_signature));
    if ($already_signed != 'not signed') {
        $crosssell_check_hfymp_checked = false;
        return false;
    }

    $crosssell_check_hfymp_checked = $auth_signature;
    return $auth_signature;
}

$crosssell_check_twfy_checked = null;
function crosssell_check_twfy($email, $postcode) {
    global $crosssell_check_twfy_checked;
    if (!is_null($crosssell_check_twfy_checked))
        return $crosssell_check_twfy_checked;

    if (!defined('OPTION_AUTH_SHARED_SECRET') || !$postcode)
        return false;

    // Look up who the MP is
    global $crosssell_voting_areas;
    if (!$crosssell_voting_areas)
        $crosssell_voting_areas = mapit_get_voting_areas($postcode);
    mapit_check_error($crosssell_voting_areas);
    if (!array_key_exists('WMC', $crosssell_voting_areas)) {
        $crosssell_check_twfy_checked = false;
        return false;
    }
    $reps = dadem_get_representatives($crosssell_voting_areas['WMC']);
    dadem_check_error($reps);
    if (count($reps) != 1) {
        $crosssell_check_twfy_checked = false;
        return false;
    }
    $rep_info = dadem_get_representative_info($reps[0]);
    dadem_check_error($rep_info);

    if (!array_key_exists('parlparse_person_id', $rep_info)) {
        $crosssell_check_twfy_checked = false;
        return false;
    }
    $person_id = str_replace('uk.org.publicwhip/person/', '', $rep_info['parlparse_person_id']);
    if (!$person_id) {
        $crosssell_check_twfy_checked = false;
        return false;
    }

    $auth_signature = auth_sign_with_shared_secret($email, OPTION_AUTH_SHARED_SECRET);
    // See if already signed up
    $already_signed = crosssell_fetch_page('www.theyworkforyou.com', '/alert/authed.php?pid='.$person_id.'&email='.urlencode($email).'&sign='.urlencode($auth_signature));
    if ($already_signed != 'not signed') {
        $crosssell_check_twfy_checked = false;
        return false;
    }

    $crosssell_check_twfy_checked = array($person_id, $auth_signature);
    return $crosssell_check_twfy_checked;
}

function crosssell_fetch_page($host, $url) {
    err($host);
    $fp = fsockopen($host, 80, $errno, $errstr, 5);
    if (!$fp)
        return false;
    stream_set_blocking($fp, 0);
    stream_set_timeout($fp, 5);
    $sockstart = getmicrotime();
    fputs($fp, "GET $url HTTP/1.0\r\nHost: $host\r\n\r\n");
    $response = '';
    $body = false;
    while (!feof($fp) and (getmicrotime() < $sockstart + 5)) {
        $s = fgets($fp, 1024);
        if ($body)
            $response .= $s;
        if ($s == "\r\n")
            $body = true;
    }
    fclose($fp);
    return $response;
}
