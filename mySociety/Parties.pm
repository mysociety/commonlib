#!/usr/bin/perl
#
# mySociety/Parties.pm:
# Political party definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Parties.pm,v 1.4 2005-02-03 13:53:08 chris Exp $
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

    "DUP" => "DUP",
    "DU" => "DUP",

    "Green" => "Green",

    "Ind" => "Independent",

    "Labour" => "Labour",
    "Lab" => "Labour",
    "Lab/Co-op" => "Labour / Co-operative",

    "LDem" => "Liberal Democrat",
    "Liberal Democrat" => "Liberal Democrat",

    "PC" => "Plaid Cymru",
    "Plaid Cymru" => "Plaid Cymru",

    "SDLP" => "SDLP",

    "SNP" => "SNP",

    "SSP" => "SSP",

    # Scottish Senior Citizens United Party
    "SSCUP" => "SSCUP",

    "SPK" => "Speaker",
    "DCWM" => "Deputy Speaker",
    "CWM" => "Deputy Speaker",

    "SF" => "Sinn Féin",
    "Sinn Fein" => "Sinn Féin",

    "UK Independence" => "UK Independence",

    "UU" => "UUP",
    "UUP" => "UUP",

    # Latest Robert Kilroy-Silk vehicle
    "Veritas" => "Veritas"
);

# Ensure that canonical party values are themselves canonical....
foreach (values(%mySociety::Parties::canonical)) {
    $mySociety::Parties::canonical{$_} ||= $_;
}

1;
