#!/usr/bin/perl
#
# mySociety/StringUtils.pm:
# Miscellaneous string handling utilities.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: StringUtils.pm,v 1.7 2009-01-26 14:21:52 matthew Exp $
#

package mySociety::StringUtils;

use strict;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&trim &merge_spaces &string_diff);
}
our @EXPORT_OK;

use String::Ediff;

=head1 NAME

mySociety::StringUtils

=head1 DESCRIPTION

Various useful string related functions for applications.

=head1 FUNCTIONS

=over 4

=item trim STRING

Remove whitespace from either end.

=cut
sub trim ($) {
    ($_) = @_;
    s/^\s+//;     s/\s+$//;
    return $_;
}

=item merge_spaces STRING

Replace contiguous whitespace (including linebreaks) with a single space.

=cut
sub merge_spaces ($) {
    ($_) = @_;
    s/\p{IsSpace}+/ /gs;
    return $_;
}

=item string_diff FROM TO

Compare the string FROM to TO. Returns a reference to a list containing
information about the differences; each element is either a pair of substrings,
the first of which appears only in FROM and the second only in TO, or a single
string which is common to both. Whitespace in FROM and TO is ignored.

=cut
sub string_diff ($$) {
    my ($from, $to) = @_;

    $from = merge_spaces($from);
    $to = merge_spaces($to);

    # String::Ediff::ediff returns -- get this -- a space-separated string
    # containing eight-item records.
    my @ix = split(" ", String::Ediff::ediff($from, $to));

    my @ret = ( );
    
    # Where we've got to in each string.
    my $s1at = 0;
    my $s2at = 0;
    my @diff;
    for (my $i = 0; $i < @ix; $i += 8) {
        # Consider differing part.
        @diff = ('', '');
        $diff[0] = substr($from, $s1at, $ix[$i + 0] - $s1at)
            if ($ix[$i + 0] > $s1at);
        $s1at = $ix[$i + 1];

        $diff[1] = substr($to, $s2at, $ix[$i + 4] - $s2at)
            if ($ix[$i + 4] > $s2at);
        $s2at = $ix[$i + 5];
        
        push(@ret, [@diff]) if ($diff[0] || $diff[1]);

        # Consider common part.
        push(@ret, substr($from, $ix[$i + 0], $ix[$i + 1] - $ix[$i + 0]))
            if ($ix[$i + 1] > $ix[$i + 0]);
    }
    @diff = ('', '');
    $diff[0] = substr($from, $s1at) if ($s1at < length($from));
    $diff[1] = substr($to, $s2at) if ($s2at < length($to));
    push(@ret, [@diff]) if ($diff[0] || $diff[1]);

    return \@ret;
}

=item break_into_lumps CONTENT

Converts HTML into space-trimmed, comment-removed lumps in an array.
Each lump was separated by a "paragraph" level tag.  Not just P, but also
e.g. TD or LI.

=cut
sub break_into_lumps ($) {
    my ($content) = @_;

    $content =~ s/&amp;/&/g;  # make ampersands normal
    $content =~ s/&nbsp;/ /g;  # make ampersands normal
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
