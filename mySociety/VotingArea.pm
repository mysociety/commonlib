#!/usr/bin/perl
#
# mySociety/VotingArea.pm:
# Voting area definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: VotingArea.pm,v 1.4 2004-10-18 16:48:14 francis Exp $
#

package mySociety::VotingArea;

use strict;

=head1 NAME

mySociety::VotingArea

=head1 DESCRIPTION

Definitions of different types of voting and administrative areas, used in
DaDem, MaPit, etc.

=head1 CONSTANTS

(The three-letter codes used here are the mostly those used in the Ordnance
Survey's BoundaryLine product to identify different types of areas.)

=over 4

=item LBO (101)

London Borough

=item LBW (102)

London Borough ward

=item GLA (201)

London Assembly

=item LAC (202)

London constituency

=item CTY (301)

County

=item CED (302)

County electoral division

=item DIS (401)

District

=item DIW (402)

District ward

=item UTA (501)

Unitary Authority

=item UTE (502)

Unitary Authority electoral division

=item UTW (503)

Unitary Authority ward

=item MTD (601)

Metropolitan District

=item MTW (602)

Metropolitan District ward

=item SPA (701)

Scottish Parliament (this code is a placeholder).

=item SPE (702)

Scottish Parliament electoral region

=item SPC (703)

Scottish Parliament constituency

=item WAS (801)

Welsh Assembly

=item WAE (802)

Welsh Assembly electoral region

=item WAC (803)

Welsh Assembly constituency

=item WMP (901)

House of Commons

=item WMC (902)

Westminster constituency

=item EUP (1001)

European Parliament

=item EUR (1002)

European Parliament region

=back

=cut

use constant LBO => 101; # London Borough
use constant LBW => 102; # ... ward

use constant GLA => 201; # Greater London Assembly
use constant LAC => 202; # London constituency

use constant CTY => 301; # County
use constant CED => 302; # ... electoral division

use constant DIS => 401; # District
use constant DIW => 402; # ... ward

use constant UTA => 501; # Unitary authority
use constant UTE => 502; # ... electoral division
use constant UTW => 503; # ... ward

use constant MTD => 601; # Metropolitan district
use constant MTW => 602; # ... ward

use constant SPA => 701; # Scottish Parliament
use constant SPE => 702; # ... electoral region
use constant SPC => 703; # ... constituency

use constant WAS => 801; # Welsh Assembly
use constant WAE => 802; # ... electoral region
use constant WAC => 803; # ... constituency

use constant WMP => 901; # Westminster Parliament
use constant WMC => 902; # ... constituency

use constant EUP => 1001; # European Parliament
use constant EUR => 1002; # ... region

=item %type_to_id

Map a 3-letter type string (like "WMC") to its corresponding numeric type.

=cut
{
    no strict 'refs';
    %mySociety::VotingArea::type_to_id = map { $_ => &$_ } qw(
            LBO LBW GLA LAC CTY CED DIS DIW UTA UTE UTW MTD MTW SPA SPE SPC WAS WAE WAC WMP WMC EUP EUR
        );
}

=item type_name

Names of types of areas. For administrative areas, this is their full name, for
instance "County" or "London Borough"; for voting areas, it's a short name, for
instance "Ward" or "Electoral Division".

=cut

%mySociety::VotingArea::type_name = (
        LBO,  "London Borough",
        LBW,  "Ward",

        GLA,  "London Assembly",
        LAC,  "Constituency",

        CTY,  "County",
        CED,  "Electoral Division",

        DIS,  "District",
        DIW,  "Ward",

        UTA,  "Unitary Authority",
        UTE,  "Electoral Division",
        UTW,  "Ward",

        MTD,  "Metropolitan District",
        MTW,  "Ward",

        SPA,  "Scottish Parliament",
        SPE,  "Electoral Region",
        SPC,  "Constituency",

        WAS,  "Welsh Assembly",
        WAE,  "Electoral Region",
        WAC,  "Constituency",

        WMP,  "House of Commons",
        WMC,  "Constituency",

        EUP,  "European Parliament",
        EUR,  "Region"
    );

=item attend_prep

Whether to use the preposition "on" or "at the" to describe someone attending
the elected body. For instance, "Your District Councillors represent you on
Cambridge District Council"; "Your Members of the European Parliament represent
you in the European Parliament".

=cut

%mySociety::VotingArea::attend_prep = (
        LBO,  "on the",

        GLA,  "on the",

        CTY,  "on",

        DIS,  "on",

        UTA,  "on",

        MTD,  "on",

        SPA,  "in the",

        WAS,  "on the",

        WMP,  "in the",

        EUP,  "in the",
    );


=item rep_name

For voting areas, gives the name of the type of person who represents that
area.  For example, "Councillor" or "Member of the European Parliament".

=cut
%mySociety::VotingArea::rep_name = (
        LBW, 'Councillor',

        GLA, 'Mayor', # "of London"? 
        LAC, 'Assembly Member',

        CED, 'County Councillor',

        DIW, 'District Councillor',

        UTE, 'Councillor',
        UTW, 'Councillor',

        MTW, 'Councillor',

        SPE, 'Member of the Scottish Parliament',
        SPC, 'Member of the Scottish Parliament',

        WAE, 'Welsh Assembly Member',
        WAC, 'Welsh Assembly Member',

        WMC, 'Member of Parliament',

        EUR, 'Member of the European Parliament'
    );

=item rep_name_plural

Plural version of rep_name.

=cut

%mySociety::VotingArea::rep_name_plural = (
        LBW, 'Councillors',

        GLA, 'Mayors', # "of London"?
        LAC, 'Assembly Members',

        CED, 'County Councillors',

        DIW, 'District Councillors',

        UTE, 'Councillors',
        UTW, 'Councillors',

        MTW, 'Councillors',

        SPE, 'Members of the Scottish Parliament',
        SPC, 'Members of the Scottish Parliament',

        WAE, 'Welsh Assembly Members',
        WAC, 'Welsh Assembly Members',

        WMC, 'Members of Parliament',

        EUR, 'Members of the European Parliament'
    );


=item rep_suffix

For voting areas, gives the suffix to the title of the person who repesents
that area.  For example, "AM" for Assembly Members.

=cut

%mySociety::VotingArea::rep_suffix = (
        LBW, '',

        GLA, '',
        LAC, 'AM',

        CED, '',

        DIW, '',

        UTE, '',
        UTW, '',

        MTW, '',

        SPE, 'MSP',
        SPC, 'MSP',

        WAE, 'AM',
        WAC, 'AM',

        WMC, 'MP',

        EUR, 'MEP'
    );

=item rep_prefix

For voting areas, gives the prefix to the title of the person who repesents
that area.  For example, "Cllr" for Councillors.

=cut
%mySociety::VotingArea::rep_prefix = (
        LBW, 'Cllr',

        GLA, 'Mayor', # "of London"? 
        LAC, '',

        CED, 'Cllr',

        DIW, 'Cllr',

        UTE, 'Cllr',
        UTW, 'Cllr',

        MTW, 'Cllr',

        SPE, '',
        SPC, '',

        WAE, '',
        WAC, '',

        WMC, '',

        EUR, ''
    );

1;
