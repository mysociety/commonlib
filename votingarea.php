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
 * $Id: votingarea.php,v 1.21 2005-01-19 14:45:32 francis Exp $
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

        'WAE' => 'WAS',
        'WAC' => 'WAS',

        'NIE' => 'NIA',

        'WMC' => 'WMP',

        'EUR' => 'EUP'
    );

/* va_display_order
 * Suggested "increasing power" display order for representatives. In cases
 * where one category of representatives is elected on a constituency and an
 * electoral area, as with top-up lists in the Scottish Parliament, an array of
 * the equivalent types is placed in this array. XXX should this be in FYR? */
$va_display_order = array(
        /* District councils */
        'DIW', 'LBW',
        /* unitary-type councils */
        'MTW', 'UTW', 'UTE', 'LGW',
        /* county council */
        'CED',
        /* various devolved assemblies */
        array('LAC', 'LAE'),
        array('WAC', 'WAE'),
        array('SPC', 'SPE'),
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
    'LBO' =>
            "The London Borough Council is responsible for
            <strong>local services</strong>, including <strong>planning</strong>, <strong>council housing</strong>,
            <strong>rubbish collection</strong>, and <strong>local roads</strong>.",
    'GLA' => "
The Greater London Assembly <strong>examines</strong> the Mayor of London's
activities, <strong>investigates</strong> issues of importance to Londoners,
and <strong>makes proposals</strong> to the Mayor.  Areas covered include the
Mayor's budget, <strong>culture, <strong>sport and tourism</strong>,
<strong>health</strong>, <strong>planning and <strong>transport</strong>.
",
    'MTD' =>
            "The Metropolitan District Council is
            responsible for all aspects of local services and policy, including
            planning, transport, education, social services and libraries.",
    'UTA' => 
            "The Unitary Authority is
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
    'SPA' => "
The Scottish Parliament is responsible for a wide range of <strong>devolved
matters</strong> in which it sets policy independently of the London
Parliament. Devolved matters include <strong>education</strong>,
<strong>health</strong>, <strong>agriculture</strong>, <strong>justice</strong>
and <strong>prisons</strong>. It also has some tax-raising powers.
",
    'WAS' => "
The National Assembly for Wales has a wide range of powers over areas including
<strong>economic development</strong>, <strong>transport</strong>,
<strong>finance</strong>, <strong>local government</strong>,
<strong>health</strong>, <strong>housing</strong> and <strong>the Welsh
Language</strong>.
"
    );

?>
