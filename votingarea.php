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
 * $Id: votingarea.php,v 1.4 2004-11-18 08:58:38 francis Exp $
 * 
 */

/* Manifest constants for different types of areas. Larger numbers indicate
 * larger areas and "more important" bodies. */
define('VA_DIS', 101);  /* District */
define('VA_DIW', 102);  /* ... ward */

define('VA_LBO', 201);  /* London Borough */
define('VA_LBW', 202);  /* ... ward */

define('VA_MTD', 301);  /* Metropolitan district */
define('VA_MTW', 302);  /* ... ward */

define('VA_UTA', 401);  /* Unitary authority */
define('VA_UTE', 402);  /* ... electoral division */
define('VA_UTW', 403);  /* ... ward */

define('VA_CTY', 501);  /* County */
define('VA_CED', 502);  /* ... electoral division */

define('VA_GLA', 601);  /* Greater London Assembly */
define('VA_LAC', 602);  /* London constituency */
define('VA_LAE', 603);  /* ... electoral region */

define('VA_WAS', 701);  /* Welsh Assembly */
define('VA_WAE', 702);  /* ... electoral region */
define('VA_WAC', 703);  /* ... constituency */

define('VA_SPA', 801);  /* Scottish Parliament */
define('VA_SPE', 802);  /* ... electoral region */
define('VA_SPC', 803);  /* ... constituency */

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

        VA_MTW => VA_MTD,

        VA_SPE => VA_SPA,
        VA_SPC => VA_SPA,

        VA_WAE => VA_WAP,
        VA_WAC => VA_WAC,

        VA_WMC => VA_WMP,

        VA_EUR => VA_EUP
    );

?>
