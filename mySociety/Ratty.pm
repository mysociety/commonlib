#!/usr/bin/perl
#
# mySociety/Ratty.pm:
# Perl interface to rate-limiting.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Ratty.pm,v 1.5 2007-01-26 10:20:20 louise Exp $
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

=item test SCOPE VALUES

Invoke the rate limiter with the given VALUES (reference to hash giving, e.g.
postcode, representative ID etc.) for the supplies SCOPE (should be a subsystem
name of some kind, for instance "fyr-web". Returns undef if no rate limit was
tripped, a reference to an array of [rule ID, message] if one was, or throws an
error on failure.

=cut
sub test ($$) {
    my ($scope, $values) = @_;
    die "SCOPE must be supplied" unless (defined($scope));
    configure() if (!defined($rabx_client));
    return $rabx_client->call('Ratty.test', $scope, $values);
}

1;

=item admin_delete_rules SCOPE

I<Instance method.> Deletes all rules in the specified SCOPE.

=cut
sub admin_delete_rules($){
    my ($scope) = @_;
    die "SCOPE must be supplied" unless (defined($scope));
    configure() if (!defined($rabx_client));
    return $rabx_client->call('Ratty.admin_delete_rules', $scope);
}
