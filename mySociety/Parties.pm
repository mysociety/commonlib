#!/usr/bin/perl
#
# mySociety/VotingArea.pm:
# Political party definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Parties.pm,v 1.1 2004-12-08 08:50:50 francis Exp $
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

    "SPK" => "Speaker",
    "DCWM" => "Deputy Speaker",
    "CWM" => "Deputy Speaker",

    "SF" => "Sinn Fein",
    "Sinn Fein" => "Sinn Fein",

    "UK Independence" => "UK Independence",

    "UU" => "UUP",
    "UUP" => "UUP",
);

1;
