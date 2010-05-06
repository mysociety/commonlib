//
// geo.h:
// C versions of various map functions
//
// Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org; WWW: http://www.mysociety.org/
//
// $Id: mysociety_geo.h,v 1.2 2009-10-09 16:50:04 francis Exp $
//

/* radians deg
 * Convert degrees to radians.
 */
double radians(double deg) {
    return deg * M_PI / 180.0;
}
/* degrees rad
 * Convert radians to degrees
 */
double degrees(double rad) {
    return rad * 180.0 / M_PI;
}

#define RADIUS_OF_EARTH 6378137 /* metres */

// Convert between Latitude/Longitude and Spherical Mercator coordinates
// (with scaling factor as used on OSM, Google Maps etc. tiles)
// http://wiki.openstreetmap.org/index.php/Mercator#C
void lat_lon_to_merc(double lat, double lon, double* x, double* y) {
    *x = lon;
    *y = log(tan(M_PI/4+lat*(M_PI/180)/2)); // Y is now from -1 to 1
    *x = RADIUS_OF_EARTH * *x * M_PI / 180;
    *y = RADIUS_OF_EARTH * *y;
}
void merc_to_lat_lon(double x, double y, double* lat, double* lon) {
    *lat = 180/M_PI * (2 * atan(exp((y/(RADIUS_OF_EARTH*M_PI/180))*M_PI/180)) - M_PI/2);
    *lon = x / RADIUS_OF_EARTH / M_PI * 180;
}

/* great_circle_distance lat1(n) lon1(e) lat2(n) lon2(e) 
 * Distance over surface of the earth between lat/lon pairs.
 * Taken from pb/db/schema.sql 
 * See http://www.ga.gov.au/geodesy/datums/distance.jsp */
double great_circle_distance(const double lat1, const double lon1, const double lat2, const double lon2) {
    return RADIUS_OF_EARTH * acos(
        (sin(radians(lat1)) * sin(radians(lat2))
        + cos(radians(lat1)) * cos(radians(lat2))
        * cos(radians(lon2 - lon1)))
    );
}

