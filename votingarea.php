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
 * $Id: votingarea.php,v 1.9 2004-12-16 23:11:04 chris Exp $
 * 
 */

/* Manifest constants for different types of areas.  */
define('VA_DIS', 101);  /* District */
define('VA_DIW', 102);  /* ... ward */

define('VA_LBO', 201);  /* London Borough */
define('VA_LBW', 202);  /* ... ward */

define('VA_MTD', 301);  /* Metropolitan district */
define('VA_MTW', 302);  /* ... ward */

define('VA_UTA', 401);  /* Unitary authority */
define('VA_UTE', 402);  /* ... electoral division (in Wales and Isle of
                         * Wight) */
define('VA_UTW', 403);  /* ... ward (elsewhere)*/

define('VA_LGD', 451);  /* Local Government District (NI) */
define('VA_LGW', 452);  /* ... ward */

define('VA_CTY', 501);  /* County */
define('VA_CED', 502);  /* ... electoral division */

define('VA_GLA', 601);  /* Greater London Assembly */
define('VA_LAC', 602);  /* London constituency */
define('VA_LAE', 603);  /* ... electoral region (for top-up members)*/

define('VA_WAS', 701);  /* Welsh Assembly */
define('VA_WAE', 702);  /* ... electoral region (for top-up members)*/
define('VA_WAC', 703);  /* ... constituency */

define('VA_SPA', 801);  /* Scottish Parliament */
define('VA_SPE', 802);  /* ... electoral region (for top-up members)*/
define('VA_SPC', 803);  /* ... constituency */

define('VA_NIA', 851);  /* Northern Ireland Assembly */
define('VA_NIE', 852);  /* ... electoral region (actually coterminous with the
                         * Westminster constituencies) */

define('VA_WMP', 901);  /* Westminster Parliament */
define('VA_WMC', 902);  /* ... constituency */

define('VA_EUP', 1001); /* European Parliament */
define('VA_EUR', 1002); /* ... region */

/* va_inside
 * For any VA_ constant which refers to a voting area which is inside an
 * administrative area, there is an entry in this array saying which type of
 * area it's inside. */
$va_inside = array(
        VA_LBW => VA_LBO,

        VA_LAC => VA_GLA,
        VA_LAE => VA_GLA,

        VA_CED => VA_CTY,

        VA_DIW => VA_DIS,

        VA_UTE => VA_UTA,
        VA_UTW => VA_UTA,

        VA_LGW => VA_LGD,

        VA_MTW => VA_MTD,

        VA_SPE => VA_SPA,
        VA_SPC => VA_SPA,

        VA_WAE => VA_WAP,
        VA_WAC => VA_WAC,

        VA_NIE => VA_NIA,

        VA_WMC => VA_WMP,

        VA_EUR => VA_EUP
    );

/* va_display_order
 * Suggested "increasing power" display order for representatives. */
$va_display_order = array(
        /* District councils */
        VA_DIW, VA_LBW,
        /* unitary-type councils */
        VA_MTW, VA_UTW, VA_UTE, VA_LGW,
        /* county council */
        VA_CED,
        /* various devolved assemblies */
        VA_LAC, VA_LAE,
        VA_WAC, VA_WAE,
        VA_SPC, VA_SPE,
        VA_NIE,
        /* HoC and European Parliament */
        VA_WMC, VA_EUR
    );

/* va_salaried
 * Array indicating whether representatives at the various levels receive a
 * salary for their work. */
$va_salaried = array(
        VA_LBW => 0,

        VA_LAC => 1,
        VA_LAE => 1,

        VA_CED => 0,

        VA_DIW => 0,

        VA_UTE => 0,
        VA_UTW => 0,

        VA_LGW => 0,

        VA_MTW => 0,

        VA_SPE => 1,
        VA_SPC => 1,

        VA_WAE => 1,
        VA_WAC => 1,

        VA_NIE => 1,

        VA_WMC => 1,

        VA_EUR => 1
    );

/* va_responsibility_description
 * Responsibilities of each elected body. XXX should copy these out of
 * Whittaker's Almanac or whatever. */
$va_responsibility_description = array(
    VA_DIS =>
            "The District Council is responsible for
            <strong>local services</strong>, including <strong>planning</strong>, <strong>council housing</strong>,
            <strong>rubbish collection</strong>, and <strong>local roads</strong>.",
    VA_MTD =>
            "The Metropolitan District Council is
            responsible for all aspects of local services and policy, including
            planning, transport, education, social services and libraries.",
    VA_CTY =>
            "The County Council is responsible for <strong>local
            services</strong>, including <strong>education</strong>, <strong>social services</strong>, <strong>transport</strong> and
            <strong>libraries</strong>.",
    VA_LGD =>
            "The Local Government District is responsible for all local
            services and policy.", /* FIXME */
    VA_WMP =>
            "The House of Commons is responsible for
            <strong>making laws in the UK and for overall scrutiny of all aspects of
            government</strong>.",
    VA_EUP =>
            "They <strong>scrutinise European laws</strong> and the <strong>budget of the European Union</strong>, and provide
            <strong>oversight of the other decision-making bodies</strong>.",
)

 
?>
