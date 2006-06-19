<?php
/*
 * datetime.php:
 * Functions to do things with dates and times.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: datetime.php,v 1.1 2006-06-19 10:33:33 francis Exp $
 * 
 */

// Parse a human entered date, which can be in one of many languages, into a
// computer date.
//  $date - text string user enters for a date
//  $now - current time
//  $language - hint as to language $date is in, e.g. eo, nl
//  $country - country site is for, e.g. US
// Returns associative array of information about the date.
// Stolen from Matthew's railway script.
function datetime_parse_local_date($date, $now, $language, $country) {
    $error = 0;
    $date = preg_replace('#((\b([a-z]|on|an|of|in|the|year of our lord))|(?<=\d)(st|nd|rd|th))\b#','',$date);
    if (!$date)
        return null;

    if ($language == 'eo')
        $date = preg_replace('#((\b(de|la))|(?<=\d)-?a)\b#','',$date);
    if ($language == 'nl')
        $date = preg_replace('#(?<=\d)e\b#','',$date);

    $date = preg_replace('#^(\d+)\.(\d+)\.(\d+)$#', '$1/$2/$3', $date);

    # Remove dots, mainly for German format "23. Mai 2006"
    $date = str_replace('.', '', $date);

    # Translate foreign words to English as strtotime() is English only
    $translate = array(
    	# Spanish,Italian,Portuguese,Welsh,Russian,Esperanto,Ukranian,Dutch,German
	'Sunday' => array('domingo', 'domenica', 'dydd sul', 
        "\xd0\xb2\xd0\xbe\xd1\x81\xd0\xba\xd1\x80\xd0\xb5\xd1\x81\xd0\xb5\xd0\xbd\xd1\x8c\xd0\xb5",
        "\xd0\xbd\xd0\xb5\xd0\xb4\xd1\x96\xd0\xbb\xd1\x96", 
        "dima\xc4\x89o", 'zondag',
	),
	'Monday' => array("lunes", "lunedi", "segunda-feira", "dydd llun",
		"\xd0\xbf\xd0\xbe\xd0\xbd\xd0\xb5\xd0\xb4\xd0\xb5\xd0\xbb\xd1\x8c\xd0\xbd\xd0\xb8\xd0\xba",
		"lundo", "\xd0\xbf\xd0\xbe\xd0\xbd\xd0\xb5\xd0\xb4\xd1\x96\xd0\xbb\xd0\xba\xd0\xb0",
		"maandag", "Montag",
	),
	'Tuesday' => array("martes", "marted\xc3\xac", "terca-feira",
		"\xd0\xb2\xd1\x82\xd0\xbe\xd1\x80\xd0\xbd\xd0\xb8\xd0\xba",
		"\xd0\xb2\xd1\x96\xd0\xb2\xd1\x82\xd0\xbe\xd1\x80\xd0\xba\xd0\xb0",
		"mardo", "dinsdag", 'dydd mawrth', "Dienstag",
	),
	'Wednesday' => array("mi\xc3\xa9rcoles", "mercoled\xc3\xac", 'quarta-feira', 'dydd mercher', 
        "\xd1\x81\xd1\x80\xd0\xb5\xd0\xb4\xd0\xb0",
        "\xd1\x81\xd0\xb5\xd1\x80\xd0\xb5\xd0\xb4\xd0\xb8\xd1", 
        'merkredo', 'woensdag', "Mittwoch",
	),
	'Thursday' => array('jueves', "gioved\xc3\xac", 'quinta-feira', 'dydd iau', 
        "\xd1\x87\xd0\xb5\xd1\x82\xd0\xb2\xd0\xb5\xd1\x80\xd0\xb3", 
        "\xd1\x87\xd0\xb5\xd1\x82\xd0\xb2\xd0\xb5\xd1\x80\xd0\xb3\xd0\xb0\xd1",
	"\xc4\xb5a\xc5\xaddo",'donderdag', "Donnerstag",
	),
	'Friday' => array('viernes', "venerd\xc3\xac", 'sexta-feira', 'dydd gwener', 
        "\xd0\xbf\xd1\x8f\xd1\x82\xd0\xbd\xd0\xb8\xd1\x86\xd0\xb0",
        "\xd0\xbf'\xd1\x8f\xd1\x82\xd0\xbd\xd0\xb8\xd1\x86\xd1\x96", 
        'vendredo', 'vrijdag', "Freitag", 
	),
	'Saturday' => array("s\xc3\xa1bado", 'sabato', 'dydd sadwrn', 
        "\xd1\x81\xd1\x83\xd0\xb1\xd0\xb1\xd0\xbe\xd1\x82\xd0\xb0",
        "\xd1\x81\xd1\x83\xd0\xb1\xd0\xbe\xd1\x82\xd0\xb8",
	'sabato', 'zaterdag', "Samstag", "Satertag", "Sonnabend", 
	),
	'January' => array('enero', 'gennaio', 'janeiro', 'Ionawr', 
        "\xd1\x8f\xd0\xbd\xd0\xb2\xd0\xb0\xd1\x80\xd1\x8f", "\xd1\x81\xd1\x96\xd1\x87\xd0\xbd\xd1\x8f", 
        'januaro', 'januari', "Januar", "Jänner", 
	),
	'February' => array('febrero', 'febbraio', 'fevereiro', 'Chwefror', 
        "\xd1\x84\xd0\xb5\xd0\xb2\xd1\x80\xd0\xb0\xd0\xbb\xd1\x8f", "\xd0\xbb\xd1\x8e\xd1\x82\xd0\xbe\xd0\xb3\xd0\xbe", 
	'februaro', 'februari', "Februar", "Feber", 
	),
	'March' => array('marzo', "mar\xc3\xa7o", 'Mawrth', 
        "\xd0\xbc\xd0\xb0\xd1\x80\xd1\x82\xd0\xb0", "\xd0\xb1\xd0\xb5\xd1\x80\xd0\xb5\xd0\xb7\xd0\xbd\xd1\x8f",
	'marto', 'maart', "März", 
	),
	'April' => array('abril', 'aprile', 'Ebrill', 
        "\xd0\xb0\xd0\xbf\xd1\x80\xd0\xb5\xd0\xbb\xd1\x8f",
        "\xd0\xba\xd0\xb2\xd1\x96\xd1\x82\xd0\xbd\xd1\x8f", 
        'aprilo', "April"
	),
	'May' => array('mayo', 'maggio', 'maio', 'Mai', 
        "\xd0\xbc\xd0\xb0\xd1\x8f", "\xd1\x82\xd1\x80\xd0\xb0\xd0\xb2\xd0\xbd\xd1\x8f", 
	'majo', 'mei',
	),
	'June' => array('junio', 'giugno', 'junho', 'Mehefin', 
        "\xd0\xb8\xd1\x8e\xd0\xbd\xd1\x8f", "\xd0\xd1\x87\xd0\xb5\xd1\x80\xd0\xb2\xd0\xbd\xd1\x8f\xd1", 
	'juni', "Juni", 
	),
	'July' => array('julio', 'luglio', 'julho', 'Gorffennaf', 
        "\xd0\xb8\xd1\x8e\xd0\xbb\xd1\x8f", "\xd0\xbb\xd0\xb8\xd0\xbf\xd0\xbd\xd1\x8f",
        'juli', "Juli", 
	),
	'August' => array('agosto',  'Awst', 
        "\xd0\xb0\xd0\xb2\xd0\xb3\xd1\x83\xd1\x81\xd1\x82\xd0\xb0", "\xd1\x81\xd0\xb5\xd1\x80\xd0\xbf\xd0\xbd\xd1\x8f", 
        "a\xc5\xadgusto", 'augustus', "August", 
	),
	'September' => array('septiembre', 'settembre', 'setembro', 'Medi', 
        "\xd1\x81\xd0\xb5\xd0\xbd\xd1\x82\xd1\x8f\xd0\xb1\xd1\x80\xd1\x8f",
        "\xd0\xb2\xd0\xb5\xd1\x80\xd0\xb5\xd1\x81\xd0\xbd\xd1\x8f", 
	'septembro', "September", 
	),
	'October' => array('octubre', 'ottobre', 'outubro', 'Hydref', 
        "\xd0\xbe\xd0\xba\xd1\x82\xd1\x8f\xd0\xb1\xd1\x80\xd1\x8f", 
        "\xd0\xb6\xd0\xbe\xd0\xb2\xd1\x82\xd0\xbd\xd1\x8f",
	'oktobro', 'oktober', "Oktober", 
	),
	'November' => array('noviembre', 'novembre', 'novembro', 'Tachwedd', 
        "\xd0\xbd\xd0\xbe\xd1\x8f\xd0\xb1\xd1\x80\xd1\x8f", 
        "\xd0\xbb\xd0\xb8\xd1\x81\xd1\x82\xd0\xbe\xd0\xbf\xd0\xb0\xd0\xb4\xd0\xb0", 
        'novembro', "November", 
	),
	'December' => array('diciembre', 'dicembre', 'dezembro', 'Rhagfyr', 
        "\xd0\xb4\xd0\xb5\xd0\xba\xd0\xb0\xd0\xb1\xd1\x80\xd1\x8f",
        "\xd0\xb3\xd1\x80\xd1\x83\xd0\xb4\xd0\xbd\xd1\x8f",
	'decembro', "Dezember", 
	),
    );
    $search = array(); $replace = array();
    foreach ($translate as $english => $foreign) {
        $search[] = '/\b(' . join('|', $foreign) . ')\b/i';
        $replace[] = $english;
    }
    $date = preg_replace($search, $replace, $date);

    $epoch = 0;
    $day = null;
    $year = null;
    $month = null;
    if (preg_match('#(\d+)/(\d+)/(\d+)#',$date,$m)) {
    	# XXX: Might be better to offer back ambiguous dates for clarification?
    	if ($country == 'US') {
            $day = $m[2]; $month = $m[1];
        } else {
            $day = $m[1]; $month = $m[2];
        }
        $year = $m[3];
        if ($year<100) 
            $year += 2000;
    } elseif (preg_match('#(\d+)/(\d+)#',$date,$m)) {
    	if ($country == 'US') {
        	$day = $m[2]; $month = $m[1];
        } else {
            $day = $m[1]; $month = $m[2];
        }
        $year = date('Y');
    } elseif (preg_match('#^([0123][0-9])([01][0-9])([0-9][0-9])$#',$date,$m)) {
        $day = $m[1]; $month = $m[2]; $year = $m[3];
    } else {
        $dayofweek = date('w'); # 0 Sunday, 6 Saturday
        if (preg_match('#next\s+(sun|sunday|mon|monday|tue|tues|tuesday|wed|wednes|wednesday|thu|thur|thurs|thursday|fri|friday|sat|saturday)\b#i',$date,$m)) {
            $date = preg_replace('#next#i','this',$date);
            if ($dayofweek == 5) {
                $now = strtotime('3 days', $now);
            } elseif ($dayofweek == 4) {
                $now = strtotime('4 days', $now);
            } else {
                $now = strtotime('5 days', $now);
            }
        }
        $t = strtotime($date,$now);
        if ($t != -1) {
            $day = date('d',$t); $month = date('m',$t); $year = date('Y',$t); $epoch = $t;
        } else {
            $error = 1;
        }
    }
    if (!$epoch && $day && $month && $year) {
        $t = mktime(0,0,0,$month,$day,$year);
        $day = date('d',$t); $month = date('m',$t); $year = date('Y',$t); $epoch = $t;
    }

    if ($epoch == 0) 
        return null;

    return array('iso'=>"$year-$month-$day", 'epoch'=>$epoch, 'day'=>$day, 'month'=>$month, 'year'=>$year, 'error'=>$error);
}


