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
 * $Id: votingarea.php,v 1.49 2008-01-11 17:51:15 matthew Exp $
 * 
 */

/* va_inside
 * For any constant which refers to a voting area which is inside an
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
        'HOC' => 'HOL',

        'EUR' => 'EUP'
    );

/* $va_parent_types
Types which are bodies, rather than constituencies/wards within them */
$va_parent_types = array_unique(array_values($va_inside));

/* $va_child_types
Types which are constituencies/wards, rather than the bodies they are in */
$va_child_types = array_keys($va_inside);

/* $va_council_parent_types
Types which are local councils, such as districts, counties,
unitary authorities and boroughs. */
$va_council_parent_types = array('DIS', 'LBO', 'MTD', 'UTA', 'LGD', 'CTY', 'COI');

/* $va_council_child_types
Types which are wards or electoral divisions in councils. */
$va_council_child_types = array('DIW', 'LBW', 'MTW', 'UTE', 'UTW', 'LGE', 'CED', 'COP');

/* $va_aliases
Names for sets of representative types */
$va_aliases = array(
    /* Councillors of whatever sort */
    'council' => $va_council_child_types,
    /* MPs */
    'westminstermp' => array('WMC'),
    /* Devolved assembly members / MSPs */
    'regionalmp' => array('SPC','SPE','WAC','WAE','LAC','LAE','NIE'),
    /* MEPs */
    'mep' => array('EUR')
);

/* $va_precise_names
Names of each child type. */
$va_precise_names = array(
        'LBW' => 'London Borough Councillors',

        'LAC' => 'London Assembly Constituency Members',
        'LAE' => 'London Assembly Party List Members',

        'CED' => 'County Councillors',

        'DIW' => 'District Councillors',

        'UTE' => 'Unitary Authority ED Councillors',
        'UTW' => 'Unitary Authority Ward Councillors',

        'LGE' => 'Local Government District Councillors',

        'COP' => 'Councillors of the Isles',

        'MTW' => 'Metropolitan District Councillors',

        'SPE' => 'Scottish Parliament Party List Members',
        'SPC' => 'Scottish Parliament Constituency Members',

        'WAE' => 'Senedd Party List Members',
        'WAC' => 'Senedd Constituency Members',

        'NIE' => 'Northern Ireland Assembly Members',

        'WMC' => 'Members of Parliament',
        'HOC' => 'Members of the House of Lords',

        'EUR' => 'Members of the European Parliament'
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
        /* Westminster Parliament */
        'WMC',
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

// If you update this, also update in perllib/mySociety/VotingArea.pm
$va_type_name = array(
        'LBO' =>  "London Borough",
        'LBW' =>  "ward",

        'GLA' =>  "Greater London Authority",

        'LAS' =>  "London Assembly",
        'LAC' =>  "constituency",
        'LAE' =>  "Electoral Region",

        'CTY' =>  "County",
        'CED' =>  "Electoral Division",

        'DIS' =>  "District",
        'DIW' =>  "ward",

        'LGD' =>  "Local Council",
        'LGE' =>  "Electoral Area",

        'UTA' =>  "Unitary Authority",
        'UTE' =>  "Electoral Division",
        'UTW' =>  "ward",

        'MTD' =>  "Metropolitan District",
        'MTW' =>  "ward",

        'COI' =>  "Council of the Isles",
        'COP' =>  "parish",

        'SPA' =>  "Scottish Parliament",
        'SPE' =>  "Electoral Region",
        'SPC' =>  "constituency",

        'WAS' =>  "Senedd",
        'WAE' =>  "Electoral Region",
        'WAC' =>  "constituency",

        'NIA' =>  "Northern Ireland Assembly",
        'NIE' =>  "constituency", # These are the same as the Westminster
                                # constituencies but return several members
                                # using a proportional system. It looks like
                                # most people just refer to them as
                                # "constituencies".
        
        'WMP' =>  "House of Commons",
        'WMC' =>  "constituency",
        'HOL' =>  "House of Lords",
        'HOC' =>  "constituency",

        'EUP' =>  "European Parliament",
        'EUR' =>  "region",
    );

$va_rep_name = array(
    'LBW' => 'councillor',
    'GLA' => 'Mayor', # "of London"?
    'LAC' => 'London Assembly Member',
    'LAE' => 'London Assembly Member',
    'CED' => 'county councillor',
    'DIW' => 'district councillor',
    'LGE' => 'councillor',
    'UTE' => 'councillor',
    'UTW' => 'councillor',
    'MTW' => 'councillor',
    'COP' => 'councillor',
    'SPE' => 'MSP',
    'SPC' => 'MSP',
    'WAE' => 'MS',
    'WAC' => 'MS',
    'NIE' => 'MLA',
    'WMC' => 'MP',
    'HOC' => 'Lord',
    'EUR' => 'MEP',
);

$va_rep_name_long = array(
    'LBW' => 'councillor',
    'GLA' => 'Mayor', # "of London"?
    'LAC' => 'London Assembly Member',
    'LAE' => 'London Assembly Member',
    'CED' => 'county councillor',
    'DIW' => 'district councillor',
    'LGE' => 'councillor',
    'UTE' => 'councillor',
    'UTW' => 'councillor',
    'MTW' => 'councillor',
    'COP' => 'councillor',
    'SPE' => 'Member of the Scottish Parliament',
    'SPC' => 'Member of the Scottish Parliament',
    'WAE' => 'Member of the Senedd',
    'WAC' => 'Member of the Senedd',
    'NIE' => 'Member of the Legislative Assembly',
    'WMC' => 'Member of Parliament',
    'HOC' => 'Member of Parliament',
    'EUR' => 'Member of the European Parliament'
);

$va_rep_name_plural = array(
    'LBW' => 'councillors',
    'GLA' => 'Mayors', # "of London"?
    'LAC' => 'London Assembly Members',
    'LAE' => 'London Assembly Members',
    'CED' => 'county councillors',
    'DIW' => 'district councillors',
    'UTE' => 'councillors',
    'UTW' => 'councillors',
    'LGE' => 'councillors',
    'MTW' => 'councillors',
    'COP' => 'councillors',
    'SPE' => 'MSPs',
    'SPC' => 'MSPs',
    'WAE' => 'MSs',
    'WAC' => 'MSs',
    'NIE' => 'MLAs',
    'WMC' => 'MPs',
    'HOC' => 'Lords',
    'EUR' => 'MEPs'
);

$va_rep_name_long_plural = array(
    'LBW' => 'councillors',
    'GLA' => 'Mayors', # "of London"?
    'LAC' => 'London Assembly Members',
    'LAE' => 'London Assembly Members',
    'CED' => 'county councillors',
    'DIW' => 'district councillors',
    'UTE' => 'councillors',
    'UTW' => 'councillors',
    'LGE' => 'councillors',
    'MTW' => 'councillors',
    'COP' => 'councillors',
    'SPE' => 'Members of the Scottish Parliament',
    'SPC' => 'Members of the Scottish Parliament',
    'WAE' => 'Members of the Senedd',
    'WAC' => 'Members of the Senedd',
    'NIE' => 'Members of the Legislative Assembly',
    'WMC' => 'Members of Parliament',
    'HOC' => 'Members of Parliament',
    'EUR' => 'Members of the European Parliament'
);

$va_rep_suffix = array(
    'LAC' => 'AM',
    'LAE' => 'AM',
    'SPE' => 'MSP',
    'SPC' => 'MSP',
    'WAE' => 'MS',
    'WAC' => 'MS',
    'NIE' => 'MLA',
    'WMC' => 'MP',
    'EUR' => 'MEP'
);

$va_rep_prefix = array(
    'LBW' => 'Cllr',
    'GLA' => 'Mayor', # "of London"?
    'CED' => 'Cllr',
    'DIW' => 'Cllr',
    'UTE' => 'Cllr',
    'UTW' => 'Cllr',
    'LGE' => 'Cllr',
    'MTW' => 'Cllr',
    'COP' => 'Cllr',
);

/* va_responsibility_description
 * Responsibilities of each elected body. XXX should copy these out of
 * Whittaker's Almanac or whatever. */
$va_responsibility_description = array(
    'DIS' =>
            "The District Council is responsible for
            <strong>local services</strong>, including <strong>planning</strong>, <strong>council housing</strong>, and
            <strong>rubbish collection</strong>.",
    'LBO' => "
The Borough Council is responsible for <strong>local services</strong>,
including <strong>planning</strong>, <strong>council housing</strong>,
<strong>rubbish collection</strong>, <strong>local roads</strong>, and
<strong>public paths</strong>.
",
    'LAS' => "
Areas covered include the
Mayor's budget, <strong>culture</strong>, <strong>sport and tourism</strong>,
<strong>health</strong>, <strong>planning</strong>, <strong>transport</strong>,
and <strong>trunk roads</strong>.
",
    'MTD' =>
            "The Metropolitan District Council is
responsible for all aspects of <strong>local services and policy</strong>, including
<strong>planning</strong>, <strong>transport</strong>,
<strong>roads</strong> (except trunk roads and motorways), public rights of way,
<strong>education</strong>, <strong>social services</strong> and <strong>libraries</strong>.",
    'UTA' => 
            "The Unitary Authority is
responsible for all aspects of <strong>local services and policy</strong>, including
<strong>planning</strong>, <strong>transport</strong>,
<strong>roads</strong> (except trunk roads and motorways), public rights of way,
<strong>education</strong>, <strong>social services</strong> and <strong>libraries</strong>.",
    'COI' => "
The Council of the Isles is responsible for <strong>education</strong>,
<strong>housing</strong>, <strong>planning</strong>, <strong>water and
sewage</strong> and various other local matters including
<strong>tourism</strong>, <strong>development</strong> and running <strong>the
airport</strong>.
",
    'CTY' =>
            "The County Council is responsible for <strong>local
services</strong>, including <strong>education</strong>, <strong>social services</strong>,
<strong>transport</strong>, <strong>roads</strong>
(except trunk roads and motorways), public rights of way, and
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
They <strong>scrutinise proposed European laws</strong> and the <strong>budget of the
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
The Senedd has a wide range of powers over areas including
<strong>economic development</strong>, <strong>transport</strong>,
<strong>finance</strong>, <strong>local government</strong>,
<strong>health</strong>, <strong>housing</strong> and <strong>the Welsh
Language</strong>.
",
    'NIA' => '
The Northern Ireland Assembly has full authority over "transferred matters",
which include <strong>agriculture</strong>, <strong>education</strong>,
<strong>employment</strong>, the <strong>environment</strong> and
<strong>health</strong>.
'
    );

/* va_is_fictional_area ID
 * Does ID refer to a test area (i.e., one invented for our own purposes)? */
function va_is_fictional_area($id) {
    if ($id >= 1000001 && $id <= 1000008)
        return true;
    else
        return false;
}

/* Special area IDs (see perllib/mysociety/VotingArea.pm for more) */
$HOC_AREA_ID = 900008;

