#!/usr/bin/perl
#
# mySociety/Parties.pm:
# Political party definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Parties.pm,v 1.13 2006-04-10 11:33:32 francis Exp $
#

package mySociety::Parties;

use strict;

=head1 NAME

mySociety::Parties

=head1 DESCRIPTION

Definitions relating to Political Parties.  For example, alternative
names for them.

=item %type_name

Map names of parties to their canonical name. i.e. The name we should
display them with.

=cut
%mySociety::Parties::canonical = (
    "Alliance" => "Alliance",
    "Alliance Party of Northern Ireland" => "Alliance",

    "Bp" => "Bishop", # House of Lords
    "Bishop" => "Bishop",

    "Conservative" => "Conservative",
    "Con" => "Conservative",
    "Ind Con" => "Independent Conservative",
    "Scottish Conservative and Unionist Party" => "Conservative",
    "Scottish Conservative & Unionist Party" => "Conservative",

    "XB" => "Crossbench", # House of Lords
    "Crossbench" => "Crossbench",

    "DUP" => "DUP",
    "DU" => "DUP",
    "Democratic Unionist Party" => "DUP",

    "Forward Wales" => "Forward Wales",

    "Green" => "Green",
    "Greens" => "Green",
    "Scottish Green Party" => "Green",

    "Ind" => "Independent",

    "Labour" => "Labour",
    "Lab" => "Labour",
    "Lab/Co-op" => "Labour / Co-operative",
    "Scottish Labour" => "Labour",

    "LDem" => "Liberal Democrat",
    "Dem" => "Liberal Democrat", # House of Lords
    "Liberal Democrat" => "Liberal Democrat",
    "Scottish Liberal Democrats" => "Liberal Democrat",

    "One London Group" => "One London Group",

    "Other" => "Other", # House of Lords

    "PC" => "Plaid Cymru",
    "Plaid Cymru" => "Plaid Cymru",

    "PUP" => "PUP",
    "Progressive Unionist Party" => "PUP",

    "Res" => "Respect",
    "Respect" => "Respect",

    "SDLP" => "SDLP",

    "Scottish National Party" => "SNP",
    "SNP" => "SNP",

    "Scottish Socialist Party" => "SSP",
    "SSP" => "SSP",

    "Scottish Senior Citizens Unity Party" => "SSCUP",
    "SSCUP" => "SSCUP",

    "SPK" => "Speaker", # Westminster
    "DCWM" => "Deputy Speaker", # Westminster
    "CWM" => "Deputy Speaker", # Westminster
    "Presiding Officer" => "Presiding Officer", # Scottish Parliament

    "SF" => "Sinn Féin",
    "Sinn Fein" => "Sinn Féin",
    "Sinn Féin" => "Sinn Féin",
    "Sinn F\x{e9}in" => "Sinn Féin",

    "UK Independence Party" => "UK Independence",
    "UK Independence" => "UK Independence",

    "UU" => "UUP",
    "UUP" => "UUP",
    "Ulster Unionist Party" => "UUP",

    "UKUP" => "UKUP",
    "United Kingdom Unionist Party" => "UKUP",

    # Latest Robert Kilroy-Silk vehicle
    "Veritas" => "Veritas",

    # For Democratic Services etc.
    "NOT A PERSON" => "NOT A PERSON"
);

# Ensure that canonical party values are themselves canonical....
foreach (values(%mySociety::Parties::canonical)) {
    $mySociety::Parties::canonical{$_} ||= $_;
}

# Add upper case maps correctly.
foreach (keys(%mySociety::Parties::canonical)) {
    my $value = $mySociety::Parties::canonical{$_};
    if ($mySociety::Parties::canonical{uc($_)}) {
        die "case sensitive variation for $_" if $mySociety::Parties::canonical{uc($_)} ne $value;
    } else {
        $mySociety::Parties::canonical{uc($_)} = $value;
    }
}

1;
