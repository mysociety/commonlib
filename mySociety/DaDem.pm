#!/usr/bin/perl
#
# mySociety/DaDem.pm:
# Client interface to DaDem (via RABX).
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: DaDem.pm,v 1.8 2005-01-31 19:14:34 chris Exp $
#

package mySociety::DaDem;

use strict;

use RABX;
use mySociety::Config;

=head1 NAME

mySociety::DaDem

=head1 DESCRIPTION

Constants and RABX I<client> interface for DaDem, the Database of Democratic
Representatives.

=head1 CONSTANTS

=head2 Error codes

=over 4

=item UNKNOWN_AREA

Area ID refers to a non-existent area.

=item REP_NOT_FOUND

Representative ID refers to a non-existent representative.

=item AREA_WITHOUT_REPS

Area ID refers to an area for which no representatives are returned.

=back

=cut

use constant UNKNOWN_AREA       => 3001;
use constant REP_NOT_FOUND      => 3002;
use constant AREA_WITHOUT_REPS  => 3003;

=head2 Other codes

=over 4

=item CONTACT_FAX (101)

Means of contacting representative is fax.

=item CONTACT_EMAIL (102)

Means of contacting representative is email.

=back

=cut

use constant CONTACT_FAX        => 101;
use constant CONTACT_EMAIL      => 102;

=head1 FUNCTIONS

=over 4

=item configure [URL]

Set the URL which will be used to call the functions over RABX.  If you don't
specify the URL, mySociety configuration variable DADEM_URL will be used
instead.

=cut
my $rabx_client = undef;
sub configure (;$) {
    my ($url) = @_;
    $url = mySociety::Config::get('DADEM_URL') if !defined($url);
    $rabx_client = new RABX::Client($url) or die qq(Bad RABX URL "$url");
}

=item get_representatives ID

Given the ID of an area, return a list of the representatives returned by that
area, or, on failure, an error code.

=cut
sub get_representatives ($) {
    my ($id) = @_;
    configure() if (!defined($rabx_client));
    return $rabx_client->call('DaDem.get_representatives', $id);
}

=item get_representative_info ID

Given the ID of a representative, return a reference to a hash of information
about that representative, including:

=over 4

=item type

Numeric code for the type of voting area (for instance, CED or ward) for which
the representative is returned.

=item name

The representative's name.

=item contact_method

How to contact the representative.

=item email

The representative's email address (only specified if contact_method is
CONTACT_EMAIL).

=item fax

The representative's fax number (only specified if contact_method is
CONTACT_FAX).

=back

or, on failure, an error code.

=cut
sub get_representative_info ($) {
    my ($id) = @_;
    configure() if (!defined($rabx_client));
    return $rabx_client->call('DaDem.get_representative_info', $id);
}

1;
