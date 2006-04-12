#!/usr/bin/perl
#
# mySociety/VotingArea.pm:
# Voting area definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: VotingArea.pm,v 1.29 2006-04-12 15:10:17 francis Exp $
#

package mySociety::VotingArea;

use strict;

=head1 NAME

mySociety::VotingArea

=head1 DESCRIPTION

Definitions of different types of voting and administrative areas, used in
DaDem, MaPit, etc.

=cut

=head2 Special area IDs

These represent regions which should exist in the schema but which are not
present in Boundary Line. See if you need to update phplib/votingarea.php when
you update these.

=over 4

=item WMP_AREA_ID

ID for the area over which the House of Commons has jurisdiction (i.e., the
union of all WMCs).

=cut
use constant WMP_AREA_ID => 900000;

=item EUP_AREA_ID

Same, for European Parliament.

=cut
use constant EUP_AREA_ID => 900001;

=item LAE_AREA_ID

ID for the area for which "London-wide" members of the London assembly are
elected. Coterminous with the GLA region.

=cut
use constant LAE_AREA_ID => 900002;

=item SPA_AREA_ID

Scottish Parliament

=cut
use constant SPA_AREA_ID => 900003;

=item WAS_AREA_ID

Welsh Assembly

=cut
use constant WAS_AREA_ID => 900004;

=item NIA_AREA_ID

Northern Ireland Assembly

=cut
use constant NIA_AREA_ID => 900005;

=item LAS_AREA_ID

London Asssembly.  Coterminous with GLA.

=cut
use constant LAS_AREA_ID => 900006;

=item HOL_AREA_ID

House of Lords. Theoretically coterminous with WMP :)

=cut
use constant HOL_AREA_ID => 900007;

=item HOC_AREA_ID

House of Lords dummy constituency

=cut
use constant HOC_AREA_ID => 900008;

=back

=head1 DATA

=over 4

=item @known_types

Known 3-letter area types.

=cut
@mySociety::VotingArea::known_types = (
        'LBO', 'LBW',  # London Borough, Ward
        'GLA',         # Greater London Authority 
        'LAS', 'LAC', 'LAE', # London Assembly, Constituency, Electoral Region
        'LGD', 'LGE',  # Local Government District, Electoral Area
        'CTY', 'CED',  # County, Electoral Division
        'DIS', 'DIW',  # District, Ward
        'UTA', 'UTE', 'UTW', # Unitary Authority, Electoral Division, Ward
        'MTD', 'MTW',  # Metropolitan District, Ward
        'COI', 'COP',  # Council of the Isles (Scilly) and constituent Parish
        'SPA', 'SPE', 'SPC', # Scottish Parliament, Electoral Region, Constituency
        'WAS', 'WAE', 'WAC', # Welsh Assembly, Electoral Region, Constituency
        'NIA', 'NIE', # Northern Ireland Assembly, Electoral Region
        'WMP', 'WMC', # Westminster Parliament, Constituency
        'HOL', 'HOC', # House of Lords, Dummy constituency
        'EUP', 'EUR', # European Parliament, Region
    );

=item %known_types

Hash having an entry for each element of @known_types.

=cut
%mySociety::VotingArea::known_types = map { $_ => 1 } @mySociety::VotingArea::known_types;

=item %type_name

Map names of types of areas. For administrative areas, this is their full name,
for instance "County" or "London Borough"; for voting areas, it's a short name,
for instance "Ward" or "Electoral Division".

=cut
%mySociety::VotingArea::type_name = (
        LBO =>  "London Borough",
        LBW =>  "Ward",

        GLA =>  "Greater London Authority",

        LAS =>  "London Assembly",
        LAC =>  "Constituency",
        LAE =>  "Electoral Region",

        CTY =>  "County",
        CED =>  "Electoral Division",

        DIS =>  "District",
        DIW =>  "Ward",

        LGD =>  "Local Council",
        LGE =>  "Electoral Area",

        UTA =>  "Unitary Authority",
        UTE =>  "Electoral Division",
        UTW =>  "Ward",

        MTD =>  "Metropolitan District",
        MTW =>  "Ward",

        COI =>  "Council of the Isles",
        COP =>  "Parish",

        SPA =>  "Scottish Parliament",
        SPE =>  "Electoral Region",
        SPC =>  "Constituency",

        WAS =>  "National Assembly for Wales",
        WAE =>  "Electoral Region",
        WAC =>  "Constituency",

        NIA =>  "Northern Ireland Assembly",
        NIE =>  "Constituency", # These are the same as the Westminster
                                # constituencies but return several members
                                # using a proportional system. It looks like
                                # most people just refer to them as
                                # "constituencies".
        
        WMP =>  "House of Commons",
        WMC =>  "Constituency",
        HOL =>  "House of Lords",
        HOC =>  "Constituency",

        EUP =>  "European Parliament",
        EUR =>  "Region",
    );

=item %attend_prep

Whether to use the preposition "on" or "at the" to describe someone attending
the elected body. For instance, "Your District Councillors represent you on
Cambridge District Council"; "Your Members of the European Parliament represent
you in the European Parliament".

=cut

%mySociety::VotingArea::attend_prep = (
        LBO =>  "on the",

        LAS =>  "on the",

        CTY =>  "on",

        DIS =>  "on",

        UTA =>  "on",

        MTD =>  "on",

        COI =>  "on",

        LGD =>  "on",

        SPA =>  "in the",

        WAS =>  "on the",

        NIA =>  "on the",

        WMP =>  "in the",
        HOL =>  "in the",

        EUP =>  "in the",
    );

=item %general_prep

Whether the place needs "the" or similar before its name when used as a noun.

=cut

%mySociety::VotingArea::general_prep = (
        LBO =>  "the",

        LAS =>  "the",

        CTY =>  "",

        DIS =>  "",

        UTA =>  "",

        MTD =>  "",

        COI =>  "",

        LGD =>  "",

        SPA =>  "the",

        WAS =>  "the",

        NIA =>  "the",

        WMP =>  "the",
        HOL =>  "the",

        EUP =>  "the",
    );


=item %rep_name

For voting areas, gives the short name of the type of person who represents
that area.  For example, "Councillor" or "MEP".

=cut
%mySociety::VotingArea::rep_name = (
        LBW => 'Councillor',

        GLA => 'Mayor', # "of London"? 

        LAC => 'London Assembly Member',
        LAE => 'London Assembly Member',

        CED => 'County Councillor',

        DIW => 'District Councillor',

        LGE => 'Councillor',

        UTE => 'Councillor',
        UTW => 'Councillor',

        MTW => 'Councillor',

        COP => 'Councillor',

        SPE => 'MSP',
        SPC => 'MSP',

        WAE => 'AM',
        WAC => 'AM',

        NIE => 'MLA',

        WMC => 'MP',
        HOC => 'Lord',

        EUR => 'MEP',
    );

=item %rep_name_long

For voting areas, gives the long name of the type of person who represents that
area.  For example, "Councillor" or "Member of the European Parliament".

=cut
%mySociety::VotingArea::rep_name_long = (
        LBW => 'Councillor',

        GLA => 'Mayor', # "of London"? 

        LAC => 'London Assembly Member',
        LAE => 'London Assembly Member',

        CED => 'County Councillor',

        DIW => 'District Councillor',

        LGE => 'Councillor',

        UTE => 'Councillor',
        UTW => 'Councillor',

        MTW => 'Councillor',

        COP => 'Councillor',

        SPE => 'Member of the Scottish Parliament',
        SPC => 'Member of the Scottish Parliament',

        NIE => 'Member of the Legislative Assembly',

        WAE => 'Assembly Member',
        WAC => 'Assembly Member',

        WMC => 'Member of Parliament',
        HOC => 'Member of Parliament',

        EUR => 'Member of the European Parliament'
    );


=item %rep_name_plural

Plural short version of rep_name.

=cut
%mySociety::VotingArea::rep_name_plural = (
        LBW => 'Councillors',

        GLA => 'Mayors', # "of London"?

        LAC => 'London Assembly Members',
        LAE => 'London Assembly Members',

        CED => 'County Councillors',

        DIW => 'District Councillors',

        UTE => 'Councillors',
        UTW => 'Councillors',

        LGE => 'Councillors',

        MTW => 'Councillors',

        COP => 'Councillors',

        SPE => 'MSPs',
        SPC => 'MSPs',

        WAE => 'AMs',
        WAC => 'AMs',

        NIE => 'MLAs',

        WMC => 'MPs',
        HOC => 'Lords',

        EUR => 'MEPs'
    );

=item %rep_name_long_plural

Plural long version of rep_name.

=cut
%mySociety::VotingArea::rep_name_long_plural = (
        LBW => 'Councillors',

        GLA => 'Mayors', # "of London"?

        LAC => 'London Assembly Members',
        LAE => 'London Assembly Members',

        CED => 'County Councillors',

        DIW => 'District Councillors',

        UTE => 'Councillors',
        UTW => 'Councillors',

        LGE => 'Councillors',

        MTW => 'Councillors',

        COP => 'Councillors',

        SPE => 'Members of the Scottish Parliament',
        SPC => 'Members of the Scottish Parliament',

        WAE => 'Assembly Members',
        WAC => 'Assembly Members',

        NIE => 'Members of the Legislative Assembly',

        WMC => 'Members of Parliament',
        HOC => 'Members of Parliament',

        EUR => 'Members of the European Parliament'
    );



=item %rep_suffix

For voting areas, gives the suffix to the title of the person who repesents
that area.  For example, "AM" for Assembly Members.

=cut
%mySociety::VotingArea::rep_suffix = (
        LBW => '',

        GLA => '',

        LAC => 'AM',
        LAE => 'AM',

        CED => '',

        DIW => '',

        UTE => '',
        UTW => '',

        LGE => '',

        MTW => '',

        COP => '',

        SPE => 'MSP',
        SPC => 'MSP',

        WAE => 'AM',
        WAC => 'AM',

        NIE => 'MLA',

        WMC => 'MP',
        HOC => '', # has neither prefix or suffix as titles in names

        EUR => 'MEP'
    );

=item %rep_prefix

For voting areas, gives the prefix to the title of the person who repesents
that area.  For example, "Cllr" for Councillors.

=cut
%mySociety::VotingArea::rep_prefix = (
        LBW => 'Cllr',

        GLA => 'Mayor', # "of London"? 

        LAC => '',
        LAE => '',

        CED => 'Cllr',

        DIW => 'Cllr',

        UTE => 'Cllr',
        UTW => 'Cllr',

        LGE => 'Cllr',

        MTW => 'Cllr',

        COP => 'Cllr',

        SPE => '',
        SPC => '',

        WAE => '',
        WAC => '',

        NIE => '',

        WMC => '',
        HOC => '', # has neither prefix or suffix as titles in names

        EUR => ''
    );

=item $council_parent_types

Types which are local councils, such as districts, counties,
unitary authorities and boroughs.

=cut
our $council_parent_types = [qw(DIS LBO MTD UTA LGD CTY COI)];

=item $council_child_types

Types which are wards or electoral divisions in councils.

=cut
our $council_child_types = [qw(DIW LBW MTW UTE UTW LGE CED COP)];

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
