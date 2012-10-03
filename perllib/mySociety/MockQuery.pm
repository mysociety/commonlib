#!/usr/bin/perl -w
#
# MockQuery.pm:
# Mock query to support tests
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org/


package MockQuery;

sub new {
    my ($class, $site, $params) = @_;
    my $self = {
     site => $site,
     params => $params,
    };
    bless $self, $class;
    return $self;
}

sub header {
  
}

sub param {
  my ($self, $key) = @_;
  return $self->{params}->{$key};  
}

1;
