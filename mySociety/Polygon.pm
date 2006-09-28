#!/usr/bin/perl
#
# Polygon.pm:
# Functions relating to polygons
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Polygon.pm,v 1.1 2006-09-28 10:06:41 francis Exp $
#

use strict;
package mySociety::Polygon;

#
# Point-in-polygon tests. Do these in C, so that the performance isn't too
# miserable.
#
use Inline C => <<'EOF';
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* pnpoly NUM XX YY X Y
 * Does the point (X, Y) lie inside the NUM-point polygon with vertices
 * (XX[0], YY[0]) ... ? */
int pnpoly(int npol, double *xp, double *yp, double x, double y) {
    int i, j, c = 0;
    for (i = 0, j = npol - 1; i < npol; j = i++) {
        if ((((yp[i] <= y) && (y < yp[j])) ||
             ((yp[j] <= y) && (y < yp[i]))) &&
                (x < (xp[j] - xp[i]) * (y - yp[i]) / (yp[j] - yp[i]) + xp[i]))
          c = !c;
    }
    return c;
}

/* Hack: pass the polygon data as packed char*, so that we don't have to unpick
 * AV/SV types. */

/* poly_area NUM DATA
 * Return the area and winding order of the NUM-point polygon with vertices
 * given by DATA. Positive return values indicate ccw winding. */
double poly_area(size_t npts, char *vv) {
    /* XXX returns double because Inline::C doesn't pick up functions which
     * return float. */
    int i;
    double a;
    for (i = 0, a = 0; i < npts; ++i) {
        double x0, y0, x1, y1;
        int j;
        memcpy(&x0, vv + i * 2 * sizeof x0, sizeof x0);
        memcpy(&y0, vv + (sizeof y0) + i * 2 * sizeof y0, sizeof y0);
        j = (i + 1) % npts;
        memcpy(&x1, vv + j * 2 * sizeof x0, sizeof x0);
        memcpy(&y1, vv + (sizeof y0) + j * 2 * sizeof y0, sizeof y0);
        a += x0 * y1 - x1 * y0;
    }
    return a / 2.;
}


/* is_point_in_poly X Y NUM DATA
 * Adapter for pnpoly. X and Y are doubles of the point to check.
 * NUM is the number of points. DATA is an array of doubles,
 * containing the coordinates of each point XYXYXYX...
 */
int is_point_in_poly(double x, double y, size_t npts, char *vv) {
    static double *xx, *yy;
    static size_t nvv;
    int i;

    if (!xx || nvv < npts) {
        xx = realloc(xx, npts * sizeof *xx);
        yy = realloc(yy, npts * sizeof *yy);
        nvv = npts;
    }

    for (i = 0; i < npts; ++i) {
        memcpy(xx + i, vv + i * 2 * sizeof(double), sizeof(double));
        memcpy(yy + i, vv + sizeof(double) + i * 2 * sizeof(double), sizeof(double));
    }

    return pnpoly(npts, xx, yy, x, y);
}

EOF

sub test() {
    my $rect = pack("d*", 0.0, 0.0, 0.0, 10.0, 10.0, 10.0, 10.0, 0.0);
    print "5.0,5.0 in 10.0 unit rect: " . is_point_in_poly(5.0, 5.0, 4, $rect) . "\n";
    print "11.0,5.0 in 10.0 unit rect: " . is_point_in_poly(11.0, 5.0, 4, $rect) . "\n";
    print "mySociety::Polygon test complete\n";
}

1;
