#!/usr/bin/perl
#
# Geo/HelmertTransform.pm:
# Perform "Helmert" (linear) transformations between coordinates referenced to
# different datums.
#
# Reference:
#   http://www.gps.gov.uk/additionalInfo/images/A_guide_to_coord.pdf
#
# Copyright (c) 2005 UK Citizens Online Democracy.  This module is free
# software; you can redistribute it and/or modify it under the same terms as
# Perl itself.
# 
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: HelmertTransform.pm,v 1.11 2006-11-06 09:05:03 chris Exp $
#

package Geo::HelmertTransform;

($Geo::HelmertTransform::VERSION) = ('$Id: HelmertTransform.pm,v 1.11 2006-11-06 09:05:03 chris Exp $' =~ /^\$Id: [^\s]+,v (\d+\.\d+) /);

use strict;

=head1 NAME

Geo::HelmertTransform

=head1 SYNOPSIS

    use Geo::HelmertTransform;

    my ($lat, $lon, $h) = ...; # from OS map
    my $airy1830 = Geo::HelmertTransform::datum('Airy1830');
    my $wgs84 = Geo::HelmertTransform::datum('WGS84');

    ($lat, $lon, $h)
        = Geo::HelmertTransform::convert_datum($airy1830, $wgs84,
                                                $lat, $lon, $h);


=head1 DESCRIPTION

Perform transformations between geographical coordinates in different datums.

It is usual to describe geographical points in terms of their polar coordinates
(latitude, longitude and altitude) referenced to a "datum ellipsoid", which is
used to approximate the Earth's geoid. The latitude, longitude and altitude of
a given physical point vary depending on which datum ellipsoid is in use.
Unfortunately, a number of ellipsoids are in everyday use, and so it is often
necessary to transform geographical coordinates between different datum
ellipsoids.

Two different datum ellipsoids may differ in the locations of their centers, or
in their shape; and there may be an angle between their equatorial planes or
the meridians relative to which longitude is measured. The Helmert Transform,
which this module implements, is a linear transformation of coordinates between
pairs of datum ellipsoids in the limit of small angles of deviation between
them. 

=head1 CONVENTIONS

Latitude is expressed in degrees, positive-north; longitude in degrees,
positive-east. Heights (ellipsoid) and cartesian coordinates are in meters.

=head1 FUNCTIONS

=over 4

=cut

use constant M_PI => 3.141592654;

=item rad_to_deg RADIANS

Convert RADIANS to degrees.

=cut
sub rad_to_deg ($) {
    return 180. * $_[0] / M_PI;
}

=item deg_to_rad DEGREES

Convert DEGREES to radians.

=cut
sub deg_to_rad ($) {
    return M_PI * $_[0] / 180.;
}

=item geo_to_xyz DATUM LAT LON H

Return the Cartesian (X, Y, Z) coordinates for the geographical coordinates
(LAT, LON, H) in the given DATUM.

=cut
sub geo_to_xyz ($$$$) {
    my ($datum, $lat, $lon, $h) = @_;
    $lat = deg_to_rad($lat);
    $lon = deg_to_rad($lon);
    
    my $v = $datum->a() / sqrt(1 - $datum->e2() * sin($lat) ** 2);
    return (
            ($v + $h) * cos($lat) * cos($lon),
            ($v + $h) * cos($lat) * sin($lon),
            ((1 - $datum->e2()) * $v + $h) * sin($lat)
        );
}

=item xyz_to_geo DATUM X Y Z

Return the geographical (LAT, LON, H) coordinates for the Cartesian coordinates
(X, Y, Z) in the given DATUM. This is an iterative procedure.

=cut
sub xyz_to_geo ($$$$) {
    my ($datum, $x, $y, $z) = @_;
    my ($lat, $lat2, $lon, $h, $v, $p);
    $lon = atan2($y, $x);
    
    $p = sqrt($x**2 + $y**2);
    $lat2 = atan2($z, $p);

    my $niter = 0;
    do {
        $lat = $lat2;
        $v = $datum->a() / sqrt(1 - $datum->e2() * sin($lat) ** 2);
        $lat2 = atan2(($z + $datum->e2() * $v * sin($lat)), $p);
        die "exceeded 10000 iterations without converging in Geo::HelmertTransform::xyz_to_geo"
            if (++$niter > 10000);
    } while (abs($lat2 - $lat) > 2e-6); # about 1/10000 mile

    $h = $p / cos($lat) - $v;

    return (rad_to_deg($lat), rad_to_deg($lon), $h);
}

=item convert_datum D1 D2 LAT LON H

Given geographical coordinates (LAT, LON, H) in datum D1, return the
corresponding coordinates in datum D2. This assumes that the transformations
are small, and always converts via WGS84.

=cut
sub convert_datum ($$$$$) {
    my ($d1, $d2, $lat, $lon, $h) = @_;
    my ($x1, $y1, $z1) = geo_to_xyz($d1, $lat, $lon, $h);
    my ($x, $y, $z) = ($x1, $y1, $z1);
    if (!$d1->is_wgs84()) {
        # Transform into WGS84.
        $x = $d1->tx()
                + (1 + $d1->s()) * $x1
                - $d1->rz()      * $y1
                + $d1->ry()      * $z1;
        $y = $d1->ty()
                + $d1->rz()      * $x1
                + (1 + $d1->s()) * $y1
                - $d1->rx()      * $z1;
        $z = $d1->tz()
                - $d1->ry()      * $x1
                + $d1->rx()      * $y1
                + (1 + $d1->s()) * $z1;
    }

    my ($x2, $y2, $z2) = ($x, $y, $z);
    if (!$d2->is_wgs84()) {
        $x2 = -$d2->tx()
                + (1 - $d2->s()) * $x
                + $d2->rz()      * $y
                - $d2->ry()      * $z;
        $y2 = -$d2->ty()
                - $d2->rz()      * $x
                + (1 - $d2->s()) * $y
                + $d2->rx()      * $z;
        $z2 = -$d2->tz()
                + $d2->ry()      * $x
                - $d2->rx()      * $y
                + (1 - $d2->s()) * $z;
    }

    return xyz_to_geo($d2, $x2, $y2, $z2);
}

=item datum NAME

Return the datum of the given NAME. Currently implemented are:

=over 4

=item Airy1830

The 1830 Airy ellipsoid to which the British Ordnance Survey's National Grid is
referenced.

=item Airy1830Modified

The modified 1830 Airy ellipsoid to which the Irish Grid (as used by Ordnance
Survey Ireland and Ordnance Survey Northern Ireland); also known as the Ireland
1975 datum.

=item WGS84

The global datum used for GPS.

=back

=cut
sub datum ($) {
    return new Geo::HelmertTransform::Datum(Name => $_[0]);
}

=back

=cut

# Datum class for internal use (alternative spelling: "I can't be bothered to
# document it now").
package Geo::HelmertTransform::Datum;

use fields qw(name a b e2 tx ty tz s rx ry rz is_wgs84);

# Fields are: semi-major and -minor axes; and the x-, y-, and z-displacements,
# scale change, and rotations to transform from this datum into WGS84.
#
#                             a (m)          b               tx        ty        tz        s (ppm)   rx (sec) ry       rz
#                             -------------- --------------- --------- --------- --------- --------- -------- -------- -------
my %known_datums = (
            # from OS article above
        Airy1830          => [6_377_563.396, 6_356_256.910,  +446.448, -125.157, +542.060, -20.4894, +0.1502, +0.2470, +0.8421],
            # from http://www.osni.gov.uk/downloads/Making%20maps%20GPS%20compatible.pdf
        Airy1830Modified  => [6_377_340.189, 6_356_034.447,  +482.530, -130.596, +564.557,  +8.150,  +1.042,  +0.214,  +0.631],
#        International1924 => [6_378_388.000, 6_356_911.946,  ??? ],
        WGS84             => [6_378_137.000, 6_356_752.3141,   0.000,    0.000,    0.000,   0.0000,  0.0000,  0.0000,  0.0000]
    );

sub new ($%) {
    my ($class, %p) = @_;
    if (exists($p{Name})) {
        die "datum \"$p{Name}\" not known"
            if (!exists($known_datums{$p{Name}}));
        my @d = @{$known_datums{$p{Name}}};
        my $s = fields::new($class);
        foreach (qw(a b tx ty tz)) {
            $s->{$_} = shift(@d);
        }
        $s->{s} = shift(@d) / 1_000_000;                # ppm
        foreach (qw(rx ry rz)) {
            $s->{$_} = Geo::HelmertTransform::deg_to_rad(shift(@d) / 3600.);  # seconds
        }
        $s->{is_wgs84} = ($p{Name} eq 'WGS84');
        return $s;
    } elsif (!exists($p{a}) || !exists($p{b})) {
        die "must specify semi-major axis a and semi-minor axis b";
    } else {
        my $s = fields::new($class);
        foreach (qw(a b tx ty tz s rx ry rz)) {
            $s->{$_} = 0;
            $s->{$_} = $p{$_} if (exists($p{$_}));
        }
        $s->{is_wgs84} = 0;
        return $s;
    }
}

foreach (qw(a b tx ty tz s rx ry rz is_wgs84)) {
    eval <<EOF;
sub $_ (\$) {
    return \$_[0]->{$_};
}
EOF
}

sub e2 ($) {
    my $s = shift;
    if (!exists($_[0]->{e2})) {
        $s->{e2} = 1 - ($s->b() / $s->a()) ** 2;
    }
    return $s->{e2}
}

=head1 SEE ALSO

I<A guide to coordinate systems in Great Britain>,
http://www.gps.gov.uk/guidecontents.asp

I<Making maps compatible with GPS>,
http://www.osni.gov.uk/downloads/Making%20maps%20GPS%20compatible.pdf

=head1 AUTHOR AND COPYRIGHT

Written by Chris Lightfoot, chris@mysociety.org

Copyright (c) UK Citizens Online Democracy.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 VERSION

$Id: HelmertTransform.pm,v 1.11 2006-11-06 09:05:03 chris Exp $

=cut

1;

