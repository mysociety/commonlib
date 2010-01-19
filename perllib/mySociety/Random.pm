#!usr/bin/perl
#
# mySociety/Random.pm:
# random number utilities

package mySociety::Random;

use strict;

use Fcntl;
use IO::File;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&random_bytes);
}
our @EXPORT_OK;

=head1 NAME

mySociety::Random

=head1 DESCRIPTION

Functions for random numbers, split from mysociety::Util

=head1 FUNCTIONS

=over 4

=item random_bytes NUMBER [PSEUDORANDOM]

Return the given NUMBER of random bytes from /dev/random (or, if PSEUDORANDOM
is true, from /dev/urandom).

=cut
sub random_bytes ($;$) {
    my $count = shift;
    my $pseudo = shift;

    no utf8;

    our %random_f;
    my $device = $pseudo ? '/dev/urandom' : '/dev/random';

    if (!exists($random_f{$device})) {
        $random_f{$device} = new IO::File($device, O_RDONLY) or die "open $device: $!";
    }
    my $f = $random_f{$device};

    my $l = '';
    while (length($l) < $count) {
        my $n = $f->sysread($l, $count - length($l), length($l));
        if (!defined($n)) {
            die "read $device: $!";
        } elsif (!$n) {
            die "read $device: EOF (shouldn't happen)";
        }
    }

    die "wanted $count bytes, got " . length($l) . " bytes" unless (length($l) == $count);

    return $l;
}

1;
