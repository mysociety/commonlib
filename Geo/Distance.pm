#!/usr/bin/perl
#
# Geo/Distance.pm:
# Great-circle distance on the Earth.
#
# Copyright (c) 2005 UK Citizens Online Democracy.  This module is free
# software; you can redistribute it and/or modify it under the same terms as
# Perl itself.
#
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Distance.pm,v 1.5 2006-06-21 17:10:24 francis Exp $
#

package Geo::Distance;

use strict;

use POSIX qw(acos);

=head1 NAME

Geo::Distance

=head1 DESCRIPTION

Compute the great-circle distance between two points on the surface of the
Earth. This is an adequate approximation to the true geodesic distance for many
purposes.

=head1 FUNCTIONS

=over 4

=cut

=item R_e

The radius of the earth, in km.

=cut
use constant R_e => 6372.8; # radius of the earth in km
use constant M_PI => 3.141592654;

# rad DEGREES
# Return DEGREES in radians.
sub rad ($) {
    return M_PI * $_[0] / 180.;
}

# deg RADIANS
# Return RADIANS in degrees.
sub deg ($) {
    return 180. * $_[0] / M_PI;
}

=item distance LAT1 LON2 LAT2 LON2

Return the great-circle distance between (LAT1, LON1) and (LAT2, LON2).
Coodinates should be expressed in degrees.

=cut
sub distance ($$$$) {
    my ($lat1, $lon1, $lat2, $lon2) = map { rad($_) } @_;
    my $arg = sin($lat1) * sin($lat2) + cos($lat1) * cos($lat2) * cos($lon1 - $lon2);
    return 0 if (abs($arg) > 1); # XXX "shouldn't happen", but sometimes does when passed two equal places
    return R_e * acos(sin($lat1) * sin($lat2) + cos($lat1) * cos($lat2) * cos($lon1 - $lon2));
}

=head1 SEE ALSO

I<Calculating distance between two points>,
http://www.ga.gov.au/geodesy/datums/distance.jsp

=head1 AUTHOR AND COPYRIGHT

Written by Chris Lightfoot, chris@mysociety.org

Copyright (c) UK Citizens Online Democracy.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 VERSION

$Id: Distance.pm,v 1.5 2006-06-21 17:10:24 francis Exp $

=cut

1;
