#!/usr/bin/perl
#
# mySociety/Ratty.pm:
# Perl interface to rate-limiting.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Ratty.pm,v 1.1 2005-01-11 16:16:59 chris Exp $
#

package mySociety::Ratty;

use strict;

use RABX;
use mySociety::Config;

=head1 NAME

mySociety::Ratty

=head1 DESCRIPTION

RABX I<client> interface for Ratty, the rate limiter.

=head1 FUNCTIONS

=over 4

=item configure [URL]

Set the URL which will be used to call the functions over RABX.  If you don't
specify the URL, mySociety configuration variable RATTY_URL will be used
instead.

=cut
my $rabx_client = undef;
sub configure (;$) {
    my ($url) = @_;
    $url = mySociety::Config::get('RATTY_URL') if !defined($url);
    $rabx_client = new RABX::Client($url) or die qq(Bad RABX URL "$url");
}

=item test VALUES

Invoke the rate limiter with the given VALUES (e.g. postcode, representative ID
etc.). Returns undef if no rate limit was tripped, or a reference to an array
of [rule ID, message] if one was, or throws an error on failure.

=cut
sub test ($) {
    my ($values) = @_;
    configure() if (!defined($rabx_client));
    return $rabx_client->call('Ratty.test', $values);
}

1;
