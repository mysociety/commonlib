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
 * $Id: votingarea.php,v 1.3 2004-11-02 16:24:14 chris Exp $
 * 
 */

/* Manifest constants for different types of areas. Larger numbers indicate
 * larger areas and "more important" bodies. */
define('VA_LBO', 101);  /* London Borough */
define('VA_LBW', 102);  /* ... ward */

define('VA_GLA', 201);  /* Greater London Assembly */
define('VA_LAC', 202);  /* London constituency */
define('VA_LAE', 203);  /* ... electoral region */

define('VA_CTY', 301);  /* County */
define('VA_CED', 302);  /* ... electoral division */

define('VA_DIS', 401);  /* District */
define('VA_DIW', 402);  /* ... ward */

define('VA_UTA', 501);  /* Unitary authority */
define('VA_UTE', 502);  /* ... electoral division */
define('VA_UTW', 503);  /* ... ward */

define('VA_MTD', 601);  /* Metropolitan district */
define('VA_MTW', 602);  /* ... ward */

define('VA_SPA', 701);  /* Scottish Parliament */
define('VA_SPE', 702);  /* ... electoral region */
define('VA_SPC', 703);  /* ... constituency */

define('VA_WAS', 801);  /* Welsh Assembly */
define('VA_WAE', 802);  /* ... electoral region */
define('VA_WAC', 803);  /* ... constituency */

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
