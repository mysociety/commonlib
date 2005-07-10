#!/usr/bin/perl
#
# MaPit.pm:
# Client interface to MaPit (via RABX).
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: MaPit.pm,v 1.8 2005-07-10 00:40:23 francis Exp $
#

package mySociety::MaPit;

use strict;

use RABX;
use mySociety::Config;

=head1 NAME

mySociety::MaPit

=head1 DESCRIPTION

Constants and RABX I<client> interface for MaPit, the Magic Postcode
Interrogation Tool.

=head1 CONSTANTS

=head2 Error codes

=over 4

=item BAD_POSTCODE

String is not in the correct format for a postcode.

=item POSTCODE_NOT_FOUND

The postcode was not found in the database.

=item AREA_NOT_FOUND

The area ID refers to a non-existent area.

=back
=cut

use constant BAD_POSTCODE => 2001;
use constant POSTCODE_NOT_FOUND => 2002;
use constant AREA_NOT_FOUND => 2003;

=head1 FUNCTIONS

=over 4

=item configure [URL]

Set the RABX URL which will be used to call the functions. If you don't
specify the URL, mySociety configuration variable MAPIT_URL will be used
instead.

=cut
my $rabx_client = undef;
sub configure (;$) {
    my ($url) = @_;
    $url = mySociety::Config::get('MAPIT_URL') if !defined($url);
    $rabx_client = new RABX::Client($url) or die qq(Bad RABX proxy URL "$url");
}

=item get_voting_areas POSTCODE

On success, return a reference to a hash of the areas in which the given
POSTCODE lies. Keys in the hash are voting area types as defined in
mySociety::VotingArea, and values are the area IDs. On failure, return an
error code.

=cut
sub get_voting_areas ($) {
    my ($postcode) = @_;
    configure() if !defined $rabx_client;
    return $rabx_client->call('MaPit.get_voting_areas', $postcode);
}

=item get_voting_area_info ID

On success, return a reference to a hash giving information about the area with
the given ID, including:

=over 4

=item type

Code for the type of area (one of the constants in mySociety::VotingArea); for
instance, 'CTY' or 'SPC'.

=item name

The name of the area, as defined by the Ordnance Survey; for instance,
"Cambridgeshire County".

=back

=cut
sub get_voting_area_info ($) {
    my ($id) = @_;
    configure() if !defined $rabx_client;
    return $rabx_client->call('MaPit.get_voting_area_info', $id);
}

=item get_location POSTCODE [PARTIAL]

Return the location of the given POSTCODE. The return value is a reference to
a hash containing elements.  If PARTIAL is present set to 1, will use only
the first part of the postcode, and generate the mean coordinate.  If PARTIAL
is set POSTCODE can optionally be just the first part of the postcode.

=over 4

=item coordsyst

=item easting

=item northing

Coordinates of the point in a UTM coordinate system. The coordinate system is
identified by the coordsyst element, which is "G" for OSGB (the Ordnance Survey
"National Grid" for Great Britain) or "I" for the Irish Grid (used in the
island of Ireland).

=item wgs83_lat

=item wgs84_lon

Latitude and longitude in the WGS84 coordinate system, expressed as decimal
degrees, north- and east-positive.

=back

=cut
sub get_location ($;$) {
    my ($postcode, $partial) = @_;
    configure() if !defined $rabx_client;
    return $rabx_client->call('MaPit.get_location', $postcode, $partial);
}

1;
