#!/usr/bin/perl
#
# mySociety/StringUtils.pm:
# Miscellaneous string handling utilities.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: StringUtils.pm,v 1.1 2005-01-29 00:32:37 francis Exp $
#

package mySociety::StringUtils;

use strict;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&trim &merge_spaces);
}
our @EXPORT_OK;

=head1 NAME

mySociety::StringUtils

=head1 DESCRIPTION

Various useful string related functions for applications.

=head1 FUNCTIONS

=over 4

=item random_bytes NUMBER

Return the given NUMBER of random bytes from /dev/random.

=item trim STRING

Remove whitespace from either end.

=cut
sub trim($) {
    ($_) = @_;
    s/^\s+//;     s/\s+$//;
    return $_;
}

=item merge_spaces STRING

Replace contiguous whitespace with a single space

=cut
sub merge_spaces($) {
    ($_) = @_;
    s/\s+/ /gs;
    return $_;
} 

=item break_into_lumps CONTENT

Converts HTML into space-trimmed, comment-removed lumps in an array.
Each lump was separated by a "paragraph" level tag.  Not just P, but also
e.g. TD or LI.

=cut
sub break_into_lumps($) {
    my ($content) = @_;

    $content =~ s/&amp;/&/g;  # make ampersands normal
    $content =~ s/<!--[^>]*-->//g;  # remove comments

    # Remove, without replacing with spaces, all the tags which are character
    # spanning.  We do this by removing all those except the most common
    # paragraph spanning tags.  This is because sometimes there are errors
    # where character spanning tags (e.g. a, strong, span...) are used in
    # the middle of a name.  e.g.
    #  D A Hal</a></span></span></strong><a href="../cllrhall_da.htm">l</a><br>
    $content =~ s/<\/?(?!p|br|tr|td|div|table|hr|li|ol|ul|h[1-9])\b[^>]+>//ig;

    # Flush all spacing (including NL CR) to just space
    $content = merge_spaces($content);

    # Break it up into parts between tags.  Note the only tags left are
    # those in the regular expression above at this point.
    my @lumps = split /<[^>]+>/, $content;
    @lumps = map { trim($_) } @lumps;
    return @lumps;
}

1;
