#!/usr/bin/perl
#
# mySociety/VotingArea.pm:
# Voting area definitions.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: VotingArea.pm,v 1.1 2004-10-08 14:02:27 chris Exp $
#

package mySociety::VotingArea;

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

Greater London Assembly

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

=item WAS (701)

Welsh Assembly

=item WAE (702)

Welsh Assembly electoral region

=item WAC (702)

Welsh Assembly constituency

=item WMP (801)

House of Commons

=item WMC (802)

Westminster constituency

=item EUP (901)

European Parliament

=item EUR (902)

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

use constant WAS => 701; # Welsh Assembly
use constant WAE => 702; # ... electoral region
use constant WAC => 702; # ... constituency

use constant WMP => 801; # Westminster Parliament
use constant WMC => 802; # ... constituency

use constant EUP => 901; # European Parliament
use constant EUR => 902; # ... region

1;
