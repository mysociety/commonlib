#!/usr/bin/perl
#
# mySociety/DaDem.pm:
# Client interface to DaDem (via XMLRPC).
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: DaDem.pm,v 1.4 2004-10-20 16:55:39 chris Exp $
#

package mySociety::DaDem;

use strict;

use XMLRPC::Lite;

=head1 NAME

mySociety::DaDem

=head1 DESCRIPTION

Constants and XMLRPC I<client> interface for DaDem, the Database of Democratic
Representatives.

=head1 CONSTANTS

=head2 Error codes

=over 4

=item UNKNOWN_AREA (1)

Area ID refers to a non-existent area.

=item REP_NOT_FOUND (2)

Representative ID refers to a non-existent representative.

=item AREA_WITHOUT_REPS (3)

Area ID refers to an area for which no representatives are returned.

=back

=cut

use constant UNKNOWN_AREA       => 1;
use constant REP_NOT_FOUND      => 2;
use constant AREA_WITHOUT_REPS  => 3;

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

=item configure URL

Set the "XML-RPC proxy" URL which will be used to call the functions.

=cut
my $proxy = undef;
sub configure ($) {
    my ($url) = @_;
    $proxy = XMLRPC::Lite->proxy($url) or die qq(Bad XMLRPC proxy URL "$url");
}

=item get_representatives ID

Given the ID of an area, return a list of the representatives returned by that
area, or, on failure, an error code.

=cut
sub get_representatives ($) {
    my ($id) = @_;
    return $proxy->call('DaDem.get_representatives', $id)->result();
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
    return $proxy->call('DaDem.get_representative_info', $id)->result();
}

1;
