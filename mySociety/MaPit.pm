#!/usr/bin/perl
#
# MaPit.pm:
# Client interface to MaPit (via XMLRPC).
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: MaPit.pm,v 1.2 2004-10-20 16:55:39 chris Exp $
#

package mySociety::MaPit;

use strict;

use XMLRPC::Lite;

=head1 NAME

mySociety::MaPit

=head1 DESCRIPTION

Constants and XMLRPC I<client> interface for MaPit, the Magic Postcode
Interrogation Tool.

=head1 CONSTANTS

=head2 Error codes

=over 4

=item BAD_POSTCODE (1)

String is not in the correct format for a postcode.

=item POSTCODE_NOT_FOUND (2)

The postcode was not found in the database.

=item AREA_NOT_FOUND (3)

The area ID refers to a non-existent area.

=back
=cut

use constant BAD_POSTCODE => 1;
use constant POSTCODE_NOT_FOUND => 2;
use constant AREA_NOT_FOUND => 3;

=head1 FUNCTIONS

=over 4

=item configure URL

Set the "XML-RPC proxy" URL which will be used to call the functions.

=cut
my $proxy = undef;
sub configure ($) {
    my ($url) = @_;
    $proxy = XMLRPC::Lite->proxy($url) or die qq(Bad XMLRPC proxy URL "$url");
}

=item get_voting_areas POSTCODE

On success, return a reference to a hash of the areas in which the given
POSTCODE lies. Keys in the hash are voting area types as defined in
mySociety::VotingArea, and values are the area IDs. On failure, return an
error code.

=cut
sub get_voting_areas ($) {
    my ($postcode) = @_;
    return $proxy->call('MaPit.get_voting_areas', $postcode)->result();
}

=item get_voting_area_info ID

On success, return a reference to a hash giving information about the area with
the given ID, including:

=over 4

=item type

Numeric code for the type of area (one of the constants in
mySociety::VotingArea); for instance, CTY or SPC.

=item name

The name of the area, as defined by the Ordnance Survey; for instance,
"Cambridgeshire County".

=cut
sub get_voting_area_info ($) {
    my ($id) = @_;
    return $proxy->call('MaPit.get_voting_area_info', $id)->result();
}

1;
