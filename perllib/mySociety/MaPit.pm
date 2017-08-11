#!/usr/bin/perl
# 
# MaPit.pm:
# Client interface for MaPit.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org

package mySociety::MaPit;

use strict;

use Encode;
use JSON::MaybeXS;
use LWP::UserAgent;
use mySociety::Config;

=item configure [URL]

Set the URL which will be used to call the functions. If you don't
specify the URL, mySociety configuration variable MAPIT_URL will be used
instead.

=cut

my $base;
sub configure (;$) {
    $base = shift;
    $base = mySociety::Config::get('MAPIT_URL') if !defined($base);
    $base .= '/' unless $base =~ m{/$};
}

my $ua;

# Calls MapIt, returns the decoded JSON.
# I do it properly with HTTP status codes, then I just ignore them!
sub call ($$;%) {
    my ($url, $params, %opts) = @_;

    unless ($ua) {
        $ua = new LWP::UserAgent();
        my $api_key = mySociety::Config::get('MAPIT_API_KEY', undef);
        $ua->agent("MaPit.pm web service client");
        $ua->default_header( 'X-Api-Key' => $api_key ) if $api_key;
    }
    configure() unless $base;

    $params = join(',', @$params) if ref $params;
    my ($urlp, $after) = split '/', $url, 2;
    $urlp .= "/$params" if $params;
    $urlp .= "/$after" if $after;
    if (length($base . $urlp) > 1024) {
        $opts{URL} = $params;
    }

    my $qs = '';
    foreach my $k (keys %opts) {
        my $v = $opts{$k};
        $v = join(',', @$v) if ref $v;
        $qs .= $qs ? ';' : '';
        $qs .= "$k=$v";
    }

    my $r;
    $qs = encode_utf8($qs) if utf8::is_utf8($qs);
    $urlp = encode_utf8($urlp) if utf8::is_utf8($urlp);
    if (length($base . $urlp) > 1024) {
        $r = $ua->post($base . $url, Content => $qs);
    } elsif (length("$base$urlp?$qs") > 1024) {
        $r = $ua->post($base . $urlp, Content => $qs);
    } else {
        $urlp .= "?$qs" if $qs;
        $r = $ua->get($base . $urlp);
    }

    my $j = JSON->new->utf8->allow_nonref->decode($r->content);
    if (ref($j) eq 'HASH') {
        delete $j->{debug_db_queries};
    }
    return $j;
}

1;
