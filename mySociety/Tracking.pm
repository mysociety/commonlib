#!/usr/bin/perl
#
# mySociety/Tracking.pm:
# Perl interface to the tracking service.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Tracking.pm,v 1.1 2006-01-03 16:05:49 chris Exp $
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
    my $url = $q->url();
    my $img = mySociety::Config::get('TRACKING_URL');
    if ($img = /\?/) {
        $img .= ";";
    } else {
        $img .= "?";
    }
    $img .= "salt=$salt;url=" . urlencode($url);
    my $d = mySociety::Config::get('TRACKING_SECRET') . "\0$salt\0$url";
    if (defined($extra)) {
        $d .= "\0$extra";
        $url .= ";extra=" . urlencode($extra);
    }
    $img .= ";sign=" . Digest::SHA1::sha1_hex($d);
    return '<!- This "web bug" image is used to collect data which we use to improve our services. More on this at XXX INSERT URL WITH EXPLANATION HERE XXX --><img alt="" src="' . $img . '">';
}

1;
