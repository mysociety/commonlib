#!/usr/bin/perl
#
# mySociety/ArrayUtils.pm:
# Miscellaneous array handling utilities.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: ArrayUtils.pm,v 1.1 2005-07-14 16:46:41 francis Exp $
#

package mySociety::ArrayUtils;

use strict;

=head1 NAME

mySociety::ArrayUtils

=head1 DESCRIPTION

Various useful array related functions for applications.

=head1 FUNCTIONS

=over 4

=item symmetric_diff ARRAYREF1 ARRAYREF2

Return items which are in one of the arrays but are not in the other array.

=cut

sub symmetric_diff {
    my ($array1, $array2) = @_;

    my @union = ();
    my @intersection = ();
    my @difference = ();

    my %count = ();
    foreach my $element (@$array1, @$array2) { $count{$element}++ }
    foreach my $element (keys %count) {
            push @union, $element;
            push @{ $count{$element} > 1 ? \@intersection : \@difference }, $element;
    }
    return \@difference;
}


1;
