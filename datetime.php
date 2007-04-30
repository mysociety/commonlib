<?php
/*
 * datetime.php:
 * Functions to do things with dates and times.
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: datetime.php,v 1.7 2007-04-30 10:05:17 matthew Exp $
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
    $date = str_replace(',', ' ', $date);
    if (!$date)
        return null;

    $date = mb_strtolower($date, 'utf-8');

    if ($language == 'eo')
        $date = preg_replace('#((\b(de|la))|(?<=\d)-?a)\b#','',$date);
    if ($language == 'nl')
        $date = preg_replace('#(?<=\d)e\b#','',$date);
    if ($language == 'zh') {
        $date = preg_replace("#\xe5\xb9\xb4|\xe6\x9c\x88#", '/', $date);
        $date = preg_replace("#\xe6\x97\xa5#", '', $date);
    }

    $date = preg_replace('#^(\d+)\.(\d+)\.(\d+)$#', '$1/$2/$3', $date);

    # Remove dots, mainly for German format "23. Mai 2006"
    $date = str_replace('.', '', $date);

    # Translate foreign words to English as strtotime() is English only
    $translate = array(
        # Spanish,Italian,Portuguese,Welsh,Russian,Esperanto,Ukranian,Dutch,German,French
        'Sunday' => array('domingo', 'domenica', 'dydd sul',
            'воскресенье', 'неділя', 'dimaĉo', 'zondag', 'dimanche',
        ),
        'Monday' => array('lunes', 'lunedi', 'segunda-feira', 'dydd llun',
            'понедельник', 'lundo', 'понеділок', 'maandag', 'montag', 'lundi',
        ),
        'Tuesday' => array('martes', 'martedì', 'terca-feira', 'вторник',
            'вівторок', 'mardo', 'dinsdag', 'dydd mawrth', 'dienstag', 'mardi',
        ),
        'Wednesday' => array('miércoles', 'mercoledì', 'quarta-feira',
            'dydd mercher', 'среда', 'середа', 'merkredo', 'woensdag',
            'mittwoch', 'mercredi',
        ),
        'Thursday' => array('jueves', 'giovedì', 'quinta-feira',
            'dydd iau', 'четверг', 'четвер', 'ĵaŭdo', 'donderdag',
            'donnerstag', 'jeudi',
        ),
        'Friday' => array('viernes', 'venerdì', 'sexta-feira',
            'dydd gwener', 'пятница', "п'ятниця", 'vendredo', 'vrijdag',
            'freitag', 'vendredi',
        ),
        'Saturday' => array('sábado', 'sabato', 'dydd sadwrn', 'суббота',
            'субота', 'sabato', 'zaterdag', 'samstag', 'satertag',
            'sonnabend', 'samedi',
        ),
        'January' => array('enero', 'gennaio', 'janeiro', 'ionawr',
            'января', 'січень', 'januaro', 'januari', 'januar', 'jänner',
            'janvier',
        ),        
        'February' => array('febrero', 'febbraio', 'fevereiro',
            'chwefror', 'февраля', 'лютий', 'februaro', 'februari',
            'februar', 'feber', 'février',
        ),
        'March' => array('marzo', 'março', 'mawrth', 'марта',
            'березень', 'marto', 'maart', 'märz', 'mars',
        ),
        'April' => array('abril', 'aprile', 'ebrill', 'апреля',
            'квітень', 'aprilo', 'april', 'avril',
        ),
        'May' => array('mayo', 'maggio', 'maio', 'mai', 'мая', 'травень',
            'majo', 'mei', 'mai',
        ),
        'June' => array('junio', 'giugno', 'junho', 'mehefin', 'июня',
            'червень', 'juni', 'juni', 'juin',
        ),
        'July' => array('julio', 'luglio', 'julho', 'gorffennaf',
            'июля', 'липень', 'juli', 'juli', 'juillet',
        ),
        'August' => array('agosto', 'awst', 'августа', 'серпень',
            'aŭgusto', 'augustus', 'august', 'août',
        ),
        'September' => array('septiembre', 'settembre', 'setembro',
            'medi', 'сентября', 'вересень', 'septembro', 'september',
            'septembre',
        ),
        'October' => array('octubre', 'ottobre', 'outubro', 'hydref',
            'октября', 'жовтень', 'oktobro', 'oktober', 'oktober',
            'octobre',
        ),
        'November' => array('noviembre', 'novembre', 'novembro',
            'tachwedd', 'ноября', 'листопад', 'novembro', 'november',
            'novembre',
        ),
        'December' => array('diciembre', 'dicembre', 'dezembro',
            'rhagfyr', 'декабря', 'грудень', 'decembro', 'dezember',
            'décembre',
        )
    );
    $search = array(); $replace = array();
    foreach ($translate as $english => $foreign) {
        $search[] = '/(?:^|\s)(' . join('|', $foreign) . ')(?:\s|$)/';
        $replace[] = $english;
    }
    $date = preg_replace($search, $replace, $date);

    $epoch = 0;
    $day = null;
    $year = null;
    $month = null;
    if (preg_match('#^(\d{1,2})/(\d{1,2})/(\d{1,4})#',$date,$m)) {
        # XXX: Might be better to offer back ambiguous dates for clarification?
        if ($country == 'US') {
            $day = $m[2]; $month = $m[1];
        } else {
            $day = $m[1]; $month = $m[2];
        }
        $year = $m[3];
        if ($year<100) 
            $year += 2000;
    } elseif (preg_match('#(\d{4})/(\d{1,2})/(\d{1,2})#',$date,$m)) {
        $year = $m[1]; $day = $m[3]; $month = $m[2];
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
