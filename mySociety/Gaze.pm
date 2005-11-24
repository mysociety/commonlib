#!/usr/bin/perl
#
# mySociety/Gaze.pm:
# Client interface to Gaze (via RABX);
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Gaze.pm,v 1.1 2005-11-24 12:09:26 chris Exp $
#

package Gaze;

use strict;

use RABX;
use mySociety::Config;

=head1 NAME

mySociety::Gaze

=head1 DESCRIPTION

RABX client interface for Gaze, the gazetteer service.

=head1 FUNCTIONS

=over 4

=item configure [URL]

Set the URL which will be used to call the functions over RABX. If you don't
specify the URL, mySociety configuration variable EVEL_URL will be used instead.

=cut
my $rabx_client = undef;
sub configure (;$) {
    my ($url) = @_;
    $url = mySociety::Config::get('GAZE_URL') if !defined($url);
    $rabx_client = new RABX::Client($url) or die qq(Bad RABX URL "$url");
}

=item find_places COUNTRY STATE QUERY [MAXRESULTS [MINSCORE]]

Search for places in COUNTRY (ISO code) which match the given search QUERY.
The country must be from the list returned by get_find_places_countries.
STATE, if specified, is a customary code for a top-level administrative
subregion within the given COUNTRY; at present, this is only useful for the
United States, and should be passed as undef otherwise.  

Returns a reference to a list of [NAME, IN, NEAR, LATITUDE, LONGITUDE, STATE, SCORE].
When IN is defined, it gives the name of a region in which the place lies; when
NEAR is defined, it gives a short list of other places near to the returned
place.  These allow nonunique names to be disambiguated by the user.  LATITUDE
and LONGITUDE are in decimal degrees, north- and east-positive, in WGS84.
Earlier entries in the returned list are better matches to the query. 

At most MAXRESULTS (default, 20) results, and only results with score at least
MINSCORE (default 0, percentage from 0 to 100) are returned. The MAXRESULTS
limit is ignored when the top results all have the same relevancy. They are all
returned. So for example, this means that if you search for Cambridge in the US
with MAXRESULTS of 5, it will return all the Cambridges, even though there
are more than 5 of them.

On error, throws an exception.

=cut
sub find_places ($$$;$$) {
    configure() if (!defined($rabx_client));
    return $rabx_client->call('Gaze.find_places', @_);
}

=item get_find_places_countries

Return list of countries which find_places will work for.

=cut
sub get_find_places_countries () {
    configure() if (!defined($rabx_client));
    return $rabx_client->call('Gaze.get_find_places_countries');
}

=item get_country_from_ip ADDRESS

Return the country code for the given IP address, or undef if none could be
found.

=cut
sub get_country_from_ip ($) {
    my ($addr) = @_;
    configure() if (!defined($rabx_client));
    return $rabx_client->call('Gaze.get_country_from_ip', $addr);
}

1;
