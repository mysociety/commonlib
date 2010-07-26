#!/usr/bin/perl
# 
# MaPit.pm:
# Client interface for MaPit. Mostly monkeypatch legacy code, with a
# new call function.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org

package mySociety::MaPit;

use strict;

use JSON;
use LWP::UserAgent;
use RABX;
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
sub _call ($$;$) {
    my ($url, $params, $opts) = @_;
    unless ($ua) {
        $ua = new LWP::UserAgent();
        $ua->agent("MaPit.pm web service client");
    }
    configure() unless $base;
    $params = join(',', @$params) if ref $params;
    my ($urlp, $after) = split '/', $url, 2;
    $urlp .= "/$params" if $params;
    $urlp .= "/$after" if $after;
    if (length($base . $urlp) > 1024) {
        $opts->{URL} = $params;
    }
    my $qs = '';
    foreach my $k (keys %$opts) {
        my $v = $opts->{$k};
        $v = join(',', @$v) if ref $v;
        $qs .= $qs ? ';' : '';
        $qs .= "$k=$v";
    }
    my $r;
    if (length($base . $urlp) > 1024) {
        $r = $ua->post($base . $url, Content => $qs);
    } elsif (length("$base$urlp?$qs") > 1024) {
        $r = $ua->post($base . $urlp, Content => $qs);
    } else {
        $urlp .= "?$qs" if $qs;
        $r = $ua->get($base . $urlp);
    }
    return $r;
}

# New method of calling MaPit, just returns the decoded JSON.
# I do it properly with HTTP status codes, then I just ignore them!
sub call ($$;%) {
    my ($fn, $params, %opts) = @_;
    my $r = _call($fn, $params, \%opts);
    return JSON->new->utf8->allow_nonref->decode($r->content);
}

# Calling code still needs these, although now MaPit will return HTTP
# status codes 400 or 404 for these things.
use constant BAD_POSTCODE => 2001;
use constant POSTCODE_NOT_FOUND => 2002;
use constant AREA_NOT_FOUND => 2003;

# Old method of calling MaPit, will throw a RABX::Error if something goes wrong,
sub call_old ($$;$$) {
    my ($fn, $params, $opts, $errors) = @_;
    my $r = _call($fn, $params, $opts);
    my $out = JSON->new->utf8->allow_nonref->decode($r->content);
    if ($r->code() == 404 && $errors->{404}) {
        throw RABX::Error($out->{error}, $errors->{404});
    } elsif ($r->code() == 400 && $errors->{400}) {
        throw RABX::Error($out->{error}, $errors->{400});
    } elsif (!$r->is_success()) {
        throw RABX::Error("HTTP error for <" . $r->request->uri . ">: " . $r->status_line(), RABX::Error::TRANSPORT);
    } else {
        return $out;
    }
}

sub get_voting_areas ($;$) {
    my $params = {};
    $params->{generation} = $_[1] if $_[1];
    return call_old('get_voting_areas', $_[0], $params, { 400 => BAD_POSTCODE, 404 => POSTCODE_NOT_FOUND });
}

sub get_voting_area_info ($) {
    return call_old('get_voting_area_info', $_[0], {}, { 404 => AREA_NOT_FOUND });
}

sub get_voting_areas_info ($) {
    return call_old('get_voting_areas_info', $_[0], {}, { 404 => AREA_NOT_FOUND });
}

sub get_voting_area_by_name ($;$$) {
    my $params = {};
    $params->{type} = $_[1] if $_[1];
    $params->{min_generation} = $_[2] if $_[2];
    return call_old('get_voting_area_by_name', $_[0], $params);
}

sub get_voting_areas_by_location ($$;$$) {
    my ($coord, $method, $type, $generation) = @_;
    my $url;
    if ($coord->{easting} && $coord->{northing}) {
        $url = "27700/$coord->{easting},$coord->{northing}";
    } else {
        $url = "4326/$coord->{longitude},$coord->{latitude}";
    }

    my $params;
    $params->{type} = $type if $type;
    $params->{generation} = $generation if $generation;
    return call_old("get_voting_areas_by_location/$method", $url, $params);
}

sub get_areas_by_type ($;$) {
    my $params = {};
    $params->{min_generation} = $_[1] if $_[1];
    return call_old('get_areas_by_type', $_[0], $params);
}

sub get_example_postcode ($) {
    return call_old('get_example_postcode', $_[0]);
}

sub get_voting_area_children ($) {
    return call_old('get_voting_area_children', $_[0]);
}

sub get_location ($;$) {
    return call_old('get_location', $_[0], {}, { 400 => BAD_POSTCODE, 404 => POSTCODE_NOT_FOUND });
}

1;
