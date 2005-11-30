#!/usr/bin/perl
#
# mySociety/Parties.pm:
# Political party definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Parties.pm,v 1.10 2005-11-30 21:02:32 francis Exp $
#

package mySociety::Parties;

use strict;

=head1 NAME

mySociety::Parties

=head1 DESCRIPTION

Definitions relating to Political Parties.  For example, alternative
names for them.

=item %type_name

Map names of parties to their canonical name.

=cut
%mySociety::Parties::canonical = (
    "Conservative" => "Conservative",
    "Con" => "Conservative",
    "Ind Con" => "Independent Conservative",
    "Scottish Conservative and Unionist Party" => "Conservative",
    "Scottish Conservative & Unionist Party" => "Conservative",

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
    "Liberal Democrat" => "Liberal Democrat",
    "Scottish Liberal Democrats" => "Liberal Democrat",

    "One London Group" => "One London Group",

    "PC" => "Plaid Cymru",
    "Plaid Cymru" => "Plaid Cymru",

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

    # Latest Robert Kilroy-Silk vehicle
    "Veritas" => "Veritas",

    # For Democratic Services etc.
    "NOT A PERSON" => "NOT A PERSON"
);

# Ensure that canonical party values are themselves canonical....
foreach (values(%mySociety::Parties::canonical)) {
    $mySociety::Parties::canonical{$_} ||= $_;
}

1;
