#!/usr/bin/perl
#
# mySociety/PostcodeUtil.pm
# Postcode utilities, split from mySociety::Util.
#

package mySociety::PostcodeUtil;

use strict;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&is_valid_postcode);
}
our @EXPORT_OK;

=head1 NAME

mySociety::PostcodeUtil

=head1 DESCRIPTION

Postcode utilities, split from mySociety::Util.

=head1 FUNCTIONS

=over 4

=item is_valid_postcode STRING

Is STRING (once it has been converted to upper-case and spaces removed) a valid
UK postcode? (As defined by BS7666, apparently.)

=cut
sub is_valid_postcode ($) {
    my $pc = uc($_[0]);
    $pc =~ s#\s##g;

    # Our test postcode
    return 1 if $pc =~ m/^ZZ99Z[ZY]$/;
    
    # See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    my $in  = 'ABDEFGHJLNPQRSTUWXYZ';
    my $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    my $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    my $thd = 'ABCDEFGHJKSTUW';
    my $fth = 'ABEHMNPRVWXY';

    return 1 if (  $pc =~ m#^[$fst]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d[$thd]\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d[$fth]\d[$in][$in]$#);
    return 0;
}

=item is_valid_partial_postcode STRING

Is STRING (once it has been converted to upper-case and spaces removed) a valid
first part of a UK postcode?  e.g. WC1

=cut
sub is_valid_partial_postcode ($) {
    my $pc = uc($_[0]);
    $pc =~ s#\s##g;

    # Our test postcode
    return 1 if $pc eq 'ZZ9';
    
    # See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    my $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    my $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    my $thd = 'ABCDEFGHJKSTUW';
    my $fth = 'ABEHMNPRVWXY';
  
    return 1 if ($pc =~ m#^[$fst]\d$#
                || $pc =~ m#^[$fst]\d\d$#
                || $pc =~ m#^[$fst][$sec]\d$#
                || $pc =~ m#^[$fst][$sec]\d\d$#
                || $pc =~ m#^[$fst]\d[$thd]$#
                || $pc =~ m#^[$fst][$sec]\d[$fth]$#);
    return 0;
}

1;
