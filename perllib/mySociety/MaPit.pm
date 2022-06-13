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
use Try::Tiny;
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
    $base = encode_utf8($base) if utf8::is_utf8($base);
    $base .= '/' unless $base =~ m{/$};
}

my $ua;

# Calls MapIt, returns the decoded JSON.
# MapIt returns proper HTTP status codes, but this ignores them and passes the
# result through, assuming error will also be provided in the JSON body.
sub call ($$;%) {
    my ($url, $params, %opts) = @_;

    unless ($ua) {
        $ua = new LWP::UserAgent();
        my $api_key = mySociety::Config::get('MAPIT_API_KEY', undef);
        $ua->agent("MaPit.pm web service client");
        $ua->default_header( 'X-Api-Key' => $api_key ) if $api_key;
    }
    configure() unless $base;

    $params = get_opts_str($params);
    my ($urlp, $after) = split '/', $url, 2;
    $urlp .= "/$params" if $params;
    $urlp .= "/$after" if $after;
    if (length($base . $urlp) > 1024) {
        $opts{URL} = $params;
    }

    my $sep = mySociety::Config::get('MAPIT_API_SEPARATOR', ';');
    my $qs = join $sep, map { $_ . '=' . get_opts_str($opts{$_}) } keys %opts;

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

    my $j = JSON->new->utf8->allow_nonref;
    try {
        $j = $j->decode($r->content);
    } catch {
        # Assume an error decoding the content as JSON
        my @caller = caller(2); # 0 is catch(), 1 is try()
        my $e = "The call to $base$urlp at line $caller[2] of $caller[0] failed";
        $e .= '; it returned HTML' if $r->content_type =~ /html/;
        $e .= '; rate limit exceeded' if $r->code == 429;
        die $e;
    };
    if (ref($j) eq 'HASH') {
        delete $j->{debug_db_queries};
    }
    return $j;
}

# Given a string, returns it; given an arrayref, returns
# a string of its elements joined with ','.
sub get_opts_str {
    my $o = shift;
    return join(',', @$o) if ref $o;
    return $o;
}

1;
