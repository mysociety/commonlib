#!/usr/bin/perl
#
# mySociety/Tracking.pm:
# Perl interface to the tracking service.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Tracking.pm,v 1.3 2006-08-15 12:05:26 chris Exp $
#

package mySociety::Tracking;

use strict;

use Digest::SHA1;
use utf8;

use mySociety::Config;

sub urlencode ($) {
    my $t = shift;
    utf8::encode($t);
    $t =~ s/([^A-Za-z0-9.-])/sprintf('%%%02x', ord($1))/ge;
    return $t;
}

=item code Q [EXTRA]

=cut
sub code ($$) {
    return '' if (!mySociety::Config::get('TRACKING', 0));
    my ($q, $extra) = @_;
    my $salt = sprintf('%08x', rand(0xffffffff));
    my $url = $q->url(-path_info => 1);
    # XXX Can't use $q->query_string(), because that's reconstructed to include
    # the POST parameters too. Sigh.
    $url .= "?$ENV{QUERY_STRING}" if ($ENV{QUERY_STRING});
    my $img = mySociety::Config::get('TRACKING_URL');
    if ($img =~ /\?/) {
        $img .= ";";
    } else {
        $img .= "?";
    }
    $img .= "salt=$salt;url=" . urlencode($url);
    my $d = mySociety::Config::get('TRACKING_SECRET') . "\0$salt\0$url";
    if (defined($extra)) {
        $d .= "\0$extra";
        $img .= ";extra=" . urlencode($extra);
    }
    $img .= ";sign=" . Digest::SHA1::sha1_hex($d);
    return '<!- This "web bug" image is used to collect data which we use to improve our services. More on this at https://secure.mysociety.org/track/ --><img alt="" src="' . $img . '">';
}

1;
