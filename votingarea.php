<?php
/*
 * votingarea.php:
 * Stuff about voting and administrative areas.  "Voting Area" is the
 * terminology we use to mean any geographical region for which an
 * elected representative is returned.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org
 *
 * $Id: votingarea.php,v 1.11 2005-01-07 17:34:02 chris Exp $
 * 
 */

/* va_inside
 * For any  constant which refers to a voting area which is inside an
 * administrative area, there is an entry in this array saying which type of
 * area it's inside. */
$va_inside = array(
        'LBW' => 'LBO',

        'LAC' => 'GLA',
        'LAE' => 'GLA',

        'CED' => 'CTY',

        'DIW' => 'DIS',

        'UTE' => 'UTA',
        'UTW' => 'UTA',

        'LGW' => 'LGD',

        'MTW' => 'MTD',

        'SPE' => 'SPA',
        'SPC' => 'SPA',

        'WAE' => 'WAP',
        'WAC' => 'WAC',

        'NIE' => 'NIA',

        'WMC' => 'WMP',

        'EUR' => 'EUP'
    );

/* va_display_order
 * Suggested "increasing power" display order for representatives. XXX should
 * this be in FYR? */
$va_display_order = array(
        /* District councils */
        'DIW', 'LBW',
        /* unitary-type councils */
        'MTW', 'UTW', 'UTE', 'LGW',
        /* county council */
        'CED',
        /* various devolved assemblies */
        'LAC',
        'WAC',
        'SPC',
        'NIE',
        /* HoC and European Parliament */
        'WMC', 'EUR'
    );

/* va_salaried
 * Array indicating whether representatives at the various levels receive a
 * salary for their work. */
$va_salaried = array(
        'LBW' => 0,

        'LAC' => 1,
        'LAE' => 1,

        'CED' => 0,

        'DIW' => 0,

        'UTE' => 0,
        'UTW' => 0,

        'LGW' => 0,

        'MTW' => 0,

        'SPE' => 1,
        'SPC' => 1,

        'WAE' => 1,
        'WAC' => 1,

        'NIE' => 1,

        'WMC' => 1,

        'EUR' => 1
    );

/* va_responsibility_description
 * Responsibilities of each elected body. XXX should copy these out of
 * Whittaker's Almanac or whatever. */
$va_responsibility_description = array(
    'DIS' =>
            "The District Council is responsible for
            <strong>local services</strong>, including <strong>planning</strong>, <strong>council housing</strong>,
            <strong>rubbish collection</strong>, and <strong>local roads</strong>.",
    'MTD' =>
            "The Metropolitan District Council is
            responsible for all aspects of local services and policy, including
            planning, transport, education, social services and libraries.",
    'CTY' =>
            "The County Council is responsible for <strong>local
            services</strong>, including <strong>education</strong>, <strong>social services</strong>, <strong>transport</strong> and
            <strong>libraries</strong>.",
    'LGD' =>
            "The Local Government District is responsible for all local
            services and policy.", /* FIXME */
    'WMP' =>
            "The House of Commons is responsible for
            <strong>making laws in the UK and for overall scrutiny of all aspects of
            government</strong>.",
    'EUP' =>
            "They <strong>scrutinise European laws</strong> and the <strong>budget of the European Union</strong>, and provide
            <strong>oversight of the other decision-making bodies</strong>.",
    );

/* va_representative_category
 * For the Scottish Parliament, Welsh Assembly and Greater London Assembly,
 * there is a two-level electoral structure in which representatives are
 * elected by a first-past-the-post system on constituencies, and by a PR
 * system on larger "electoral regions". There is a key in this array for each
 * category of representative which should be displayed, with the corresponding
 * value being the list of area types on which those representatives are
 * elected. XXX should this be in FYR? */
$va_representative_category = array(
        'SPC' => array('SPC', 'SPE'),
        'WAC' => array('WAC', 'WAE'),
        'LAC' => array('LAC', 'LAE')
    );

foreach ($va_display_order as $what) {
    if ($what != 'SPE' && $what != 'WAE' && $what != 'LAE'
        && !array_key_exists($what, $va_representative_category))
        $va_representative_category[$what] = array($what);
}
 
?>
