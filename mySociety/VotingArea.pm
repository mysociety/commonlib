#!/usr/bin/perl
#
# mySociety/VotingArea.pm:
# Voting area definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: VotingArea.pm,v 1.10 2004-11-18 18:18:23 chris Exp $
#

package mySociety::VotingArea;

use strict;

=head1 NAME

mySociety::VotingArea

=head1 DESCRIPTION

Definitions of different types of voting and administrative areas, used in
DaDem, MaPit, etc.

=head1 CONSTANTS

=head2 Area type codes

(The three-letter codes used here are the mostly those used in the Ordnance
Survey's Boundary Line product to identify different types of areas.)

=over 4

=item LBO 

London Borough

=item LBW 

London Borough ward

=item GLA 

London Assembly

=item LAC 

London constituency

=item LAE 

London electoral region -- this is a fictional area type used as a placeholder
for London-wide assembly members.

=item CTY 

County

=item CED 

County electoral division

=item DIS 

District

=item DIW 

District ward

=item UTA 

Unitary Authority

=item UTE 

Unitary Authority electoral division

=item UTW 

Unitary Authority ward

=item MTD 

Metropolitan District

=item MTW 

Metropolitan District ward

=item SPA 

Scottish Parliament (this code is a placeholder).

=item SPE 

Scottish Parliament electoral region

=item SPC 

Scottish Parliament constituency

=item WAS 

Welsh Assembly

=item WAE 

Welsh Assembly electoral region

=item WAC 

Welsh Assembly constituency

=item WMP 

House of Commons

=item WMC

Westminster constituency

=item EUP

European Parliament

=item EUR 

European Parliament region

=back

=cut

use constant DIS => 101; # District
use constant DIW => 102; # ... ward

use constant LBO => 201; # London Borough
use constant LBW => 202; # ... ward

use constant MTD => 301; # Metropolitan district
use constant MTW => 302; # ... ward

use constant UTA => 401; # Unitary authority
use constant UTE => 402; # ... electoral division
use constant UTW => 403; # ... ward

use constant CTY => 501; # County
use constant CED => 502; # ... electoral division

use constant GLA => 601; # Greater London Assembly
use constant LAC => 602; # London constituency
use constant LAE => 603; # ... electoral region

use constant WAS => 701; # Welsh Assembly
use constant WAE => 702; # ... electoral region
use constant WAC => 703; # ... constituency

use constant SPA => 801; # Scottish Parliament
use constant SPE => 802; # ... electoral region
use constant SPC => 803; # ... constituency

use constant WMP => 901; # Westminster Parliament
use constant WMC => 902; # ... constituency

use constant EUP => 1001; # European Parliament
use constant EUR => 1002; # ... region

=head2 Special area IDs

These represent regions which should exist in the schema but which are not
present in Boundary Line.

=over 4

=item LAE_AREA_ID

ID for the area for which "London-wide" members of the London assembly are
elected. Coterminous with the GLA region.

=cut
use constant LAE_AREA_ID => 900002;

=item WMP_AREA_ID

ID for the area over which the House of Commons has jurisdiction (i.e., the
union of all WMCs).

=cut
use constant WMP_AREA_ID => 900000;

=item EUP_AREA_ID

Same, for European Parliament.

=cut
use constant EUP_AREA_ID => 900001;


=back

=head1 DATA

=over 4

=item %type_to_id

Map a 3-letter type string (like "WMC") to its corresponding numeric type.

=cut
{
    no strict 'refs';
    %mySociety::VotingArea::type_to_id = map { $_ => &$_ } qw(
            LBO LBW GLA LAC LAE CTY CED DIS DIW UTA UTE UTW MTD MTW SPA SPE SPC WAS WAE WAC WMP WMC EUP EUR
        );
}

=item %id_to_type

Map a numeric type to its corresponding three-letter type.

=cut
%mySociety::VotingArea::id_to_type = reverse(%mySociety::VotingArea::type_to_id);

=item %type_name

Map names of types of areas. For administrative areas, this is their full name,
for instance "County" or "London Borough"; for voting areas, it's a short name,
for instance "Ward" or "Electoral Division".

=cut
%mySociety::VotingArea::type_name = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBO,  "London Borough",
        LBW,  "Ward",

        GLA,  "London Assembly",
        LAC,  "Constituency",
        LAE,  "Electoral Region",

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

=item %attend_prep

Whether to use the preposition "on" or "at the" to describe someone attending
the elected body. For instance, "Your District Councillors represent you on
Cambridge District Council"; "Your Members of the European Parliament represent
you in the European Parliament".

=cut

%mySociety::VotingArea::attend_prep = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
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


=item %rep_name

For voting areas, gives the short name of the type of person who represents
that area.  For example, "Councillor" or "MEP".

=cut
%mySociety::VotingArea::rep_name = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBW, 'Councillor',

        GLA, 'Mayor', # "of London"? 
        LAC, 'Assembly Member',
        LAE, 'Assembly Member',

        CED, 'County Councillor',

        DIW, 'District Councillor',

        UTE, 'Councillor',
        UTW, 'Councillor',

        MTW, 'Councillor',

        SPE, 'MSP',
        SPC, 'MSP',

        WAE, 'AM',
        WAC, 'AM',

        WMC, 'MP',

        EUR, 'MEP'
    );

=item %rep_name_long

For voting areas, gives the long name of the type of person who represents that
area.  For example, "Councillor" or "Member of the European Parliament".

=cut
%mySociety::VotingArea::rep_name_long = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBW, 'Councillor',

        GLA, 'Mayor', # "of London"? 
        LAC, 'Assembly Member',
        LAE, 'Assembly Member',

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


=item %rep_name_plural

Plural short version of rep_name.

=cut
%mySociety::VotingArea::rep_name_plural = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBW, 'Councillors',

        GLA, 'Mayors', # "of London"?
        LAC, 'Assembly Members',
        LAE, 'Assembly Members',

        CED, 'County Councillors',

        DIW, 'District Councillors',

        UTE, 'Councillors',
        UTW, 'Councillors',

        MTW, 'Councillors',

        SPE, 'MSPs',
        SPC, 'MSPs',

        WAE, 'AMs',
        WAC, 'AMs',

        WMC, 'MPs',

        EUR, 'MEPs'
    );

=item %rep_name_long_plural

Plural long version of rep_name.

=cut
%mySociety::VotingArea::rep_name_long_plural = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBW, 'Councillors',

        GLA, 'Mayors', # "of London"?
        LAC, 'Assembly Members',
        LAE, 'Assembly Members',

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



=item %rep_suffix

For voting areas, gives the suffix to the title of the person who repesents
that area.  For example, "AM" for Assembly Members.

=cut
%mySociety::VotingArea::rep_suffix = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBW, '',

        GLA, '',
        LAC, 'AM',
        LAE, 'AM',

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

=item %rep_prefix

For voting areas, gives the prefix to the title of the person who repesents
that area.  For example, "Cllr" for Councillors.

=cut
%mySociety::VotingArea::rep_prefix = (
    # NB commas not => here, since otherwise the keys are interpreted as
    # strings, not their numeric values.
        LBW, 'Cllr',

        GLA, 'Mayor', # "of London"? 
        LAC, '',
        LAE, '',

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

=back

=head1 FUNCTIONS

=over 4

=item style_rep TYPE NAME

Return the full style of a representative, e.g. "Cllr Fred Fish" or "Simon Soup
MP".

=cut
sub style_rep ($$) {
    my ($type, $name) = @_;
    die "style_rep: bad TYPE $type" unless exists($mySociety::VotingArea::type_name{$type});
    return sprintf("%s%s%s",
            $mySociety::VotingArea::rep_prefix{$type} ne '' ? "$mySociety::VotingArea::rep_prefix{$type} " : '',
            $name,
            $mySociety::VotingArea::rep_suffix{$type} ne '' ? " $mySociety::VotingArea::rep_suffix{$type}" : '');
}

1;
