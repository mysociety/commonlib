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
 * $Id: votingarea.php,v 1.39 2006-04-10 08:01:09 francis Exp $
 * 
 */

/* va_inside
 * For any  constant which refers to a voting area which is inside an
 * administrative area, there is an entry in this array saying which type of
 * area it's inside. */
$va_inside = array(
        'LBW' => 'LBO',

        'LAC' => 'LAS',
        'LAE' => 'LAS',

        'CED' => 'CTY',

        'DIW' => 'DIS',

        'UTE' => 'UTA',
        'UTW' => 'UTA',

        'LGE' => 'LGD',

        'COP' => 'COI',

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
        'MTW', 'UTW', 'UTE', 'LGE', 'COP',
        /* county council */
        'CED',
        /* various devolved assemblies */
        array('LAC', 'LAE'),
        array('WAC', 'WAE'),
        array('SPC', 'SPE'),
        'NIE',
        /* Westminster Parliament and European Parliament */
        'WMC', 'HOL', 'EUR'
    );

/* va_salaried
 * Array indicating whether representatives at the various levels typically
 * receive a salary for their work. */
$va_salaried = array(
        'LBW' => 0,

        'LAC' => 1,
        'LAE' => 1,

        'CED' => 0,

        'DIW' => 0,

        'UTE' => 0,
        'UTW' => 0,

        'LGE' => 0,

        'MTW' => 0,

        'COP' => 0, /* XXX don't know but assume unpaid -- check */

        'SPE' => 1,
        'SPC' => 1,

        'WAE' => 1,
        'WAC' => 1,

        'NIE' => 1,

        'WMC' => 1,
        'HOL' => 1, /* Although in contrast to MPs, Lords are paid according to attendance */

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
    'LBO' => "
The Borough Council is responsible for <strong>local services</strong>,
including <strong>planning</strong>, <strong>council housing</strong>,
<strong>rubbish collection</strong>, and <strong>local roads</strong>.
",
    'LAS' => "
The London Assembly <strong>examines</strong> the Mayor of London's
activities, <strong>investigates</strong> issues of importance to Londoners,
and <strong>makes proposals</strong> to the Mayor.  Areas covered include the
Mayor's budget, <strong>culture</strong>, <strong>sport and tourism</strong>,
<strong>health</strong>, <strong>planning</strong> and <strong>transport</strong>.
",
    'MTD' =>
            "The Metropolitan District Council is
            responsible for all aspects of <strong>local services and policy</strong>, including
            <strong>planning</strong>, <strong>transport</strong>, <strong>education</strong>, 
            <strong>social services</strong> and <strong>libraries</strong>.",
    'UTA' => 
            "The Unitary Authority is
            responsible for all aspects of <strong>local services and policy</strong>, including
            <strong>planning</strong>, <strong>transport</strong>, <strong>education</strong>, 
            <strong>social services</strong> and <strong>libraries</strong>.",
    'COI' => "
The Council of the Isles is responsible for <strong>education</strong>,
<strong>housing</strong>, <strong>planning</strong>, <strong>water and
sewage</strong> and various other local matters including
<strong>tourism</strong>, <strong>development</strong> and running <strong>the
airport</strong>.
",
    'CTY' =>
            "The County Council is responsible for <strong>local
            services</strong>, including <strong>education</strong>, <strong>social services</strong>, <strong>transport</strong> and
            <strong>libraries</strong>.",
    'LGD' =>
            "The Local Council is responsible for
            <strong>local services</strong>, including 
            <strong>waste and recycling</strong>, 
            <strong>leisure and community</strong>, 
            <strong>building control</strong> and
            <strong>local economic and cultural development</strong>.",
    'WMP' =>
            "The House of Commons is responsible for
            <strong>making laws in the UK and for overall scrutiny of all aspects of
            government</strong>.",
    'EUP' => "
They <strong>scrutinise European laws</strong> and the <strong>budget of the
European Union</strong>, and provide <strong>oversight of its other
decision-making bodies</strong>.
",
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
",
    'NIA' => "
The Northern Ireland Assembly is currently suspended, and at the moment the
<a href=\"http://www.nics.gov.uk/gov.htm\">Northern Ireland government
departments</a> are discharging its responsibilities. When the Assembly is
sitting, it has full authority over \"transferred matters\", which include
<strong>agriculture</strong>, <strong>education</strong>,
<strong>employment</strong>, the <strong>environment</strong> and
<strong>health</strong>. Although the Assembly is suspended, members of the
Assembly have been elected and you can contact them.
"
    );

/* $va_council_parent_types

Types which are local councils, such as districts, counties,
unitary authorities and boroughs. */

$va_council_parent_types = array('DIS', 'LBO', 'MTD', 'UTA', 'LGD', 'CTY', 'COI');

/* $va_council_child_types

Types which are wards or electoral divisions in councils. */

$va_council_child_types = array('DIW', 'LBW', 'MTW', 'UTE', 'UTW', 'LGE', 'CED', 'COP');

/* va_is_fictional_area ID
 * Does ID refer to a test area (i.e., one invented for our own purposes)? */
function va_is_fictional_area($id) {
    if ($id >= 1000001 && $id <= 1000008)
        return true;
    else
        return false;
}


?>
