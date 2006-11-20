#!/usr/bin/perl
#
# mySociety/BaseN.pm:
# Arbitrary base-N encodings (like base64 etc.); and a pseudo-base-N encoding
# (a generalisation of Adobe's ASCII85) which is much faster.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: BaseN.pm,v 1.2 2006-11-20 15:12:23 matthew Exp $
#

package mySociety::BaseN;

use strict;

#
# Theory: obviously we can take an arbitrary binary string, treat it as an
# integer of arbitrary size, and turn it into a corresponding integer in
# another base. This is what the encode and decode functions below do. Note the
# subtlety that as well as the integer itself, we must communicate the total
# number of bytes encoded, so that we can reproduce the input string
# faithfully. This information is communicated implicitly in the length of the
# output string. For instance, in a naive encoding in the base 64 alphabet (in
# which "A" represents 0) you would expect "A", "AA", ... all to represent the
# number zero, and therefore a string of arbitrarily many zero bits. To resolve
# this ambiguity the length of the encoded string is used to communicate the
# length of the input; in MIME-standard base64, all output is padded to be a
# multiple of four output symbols, and "AA==" represents the byte 00, "AAA="
# the bytes 00 00, and "AAAA" the bytes 00 00 00; but we don't need the padding
# symbols, so we can just encode those cases as "AA", "AAA", and "AAAA".
#
# The pseudo-base-N encodings used by encodefast/decodefast divide the input
# message up into four-byte blocks (with potentially a short trailer) and
# base-N encode each block. Obviously this avoids the need for
# arbitrary-precision arithmetic, and is therefore much faster than the true
# base-N encodings. The implementation is made slightly hairy by perl foibles;
# if it gives trouble is should be replaced with one in C.
# 

use Carp;
use Math::BigInt lib => 'GMP';
use POSIX qw(ceil);

my $std_alpha = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

my %std_alpha_key;
for (my $i = 0; $i < length($std_alpha); ++$i) {
    $std_alpha_key{substr($std_alpha, $i, 1)} = $i;
}

sub lg ($) {
    return log($_[0]) / log(2);
}

=item encode N MESSAGE [ALPHABET]

Encode the MESSAGE in base-N, using the given ALPHABET (or a standard one if it
is not specified).

=cut
sub encode ($$;$) {
    my $n = shift;
    croak "N must be a positive integer" unless ($n =~ /^[1-9]\d*$/);
    my $message = shift;
    croak "MESSAGE may not be undef" unless (defined($message));
    my $alphabet = $std_alpha;
    if (@_) {
        $alphabet = shift;
        croak "ALPHABET may not be undef" unless (defined($alphabet));
        croak "ALPHABET must contain $n characters"
            unless (length($alphabet) == $n);
    } elsif ($n > length($alphabet)) {
        croak "not enough characters in standard alphabet -- supply your own";
    } else {
        $alphabet = substr($alphabet, 0, $n);
    }

    # Number of output symbols to generate. Obviously each input symbol encodes
    # 8 bits, and each output symbol lg(N) bits; round up to get the number of
    # output symbols required.
    my $noutput = ceil((length($message) * 8) / lg($n));
    
    my $x = new Math::BigInt();
    for (my $i = 0; $i < length($message); ++$i) {
        $x->blsft(8);
        $x->bior(unpack('C', substr($message, $i, 1)));
    }
    my $res = '';
    for (my $i = 0; $i < $noutput; ++$i) {
        my ($quo, $rem) = $x->bdiv($n);
        $res .= substr($alphabet, $rem, 1);
    }

    return scalar(reverse($res));
}


=item decode N MESSAGE [ALPHABET]

Decode the base-N MESSAGE, using the given ALPHABET (or a standard one if it is
not specified). Returns undef if MESSAGE is invalid (contains characters not in
ALPHABET).

=cut
sub decode ($$;$) {
    my $n = shift;
    croak "N must be a positive integer" unless ($n =~ /^[1-9]\d*$/);
    my $message = shift;
    croak "MESSAGE may not be undef" unless (defined($message));
    my $alphabet = $std_alpha;
    my $key = \%std_alpha_key;
    if (@_) {
        $alphabet = shift;
        croak "ALPHABET may not be undef" unless (defined($alphabet));
        croak "ALPHABET must contain $n characters"
            unless (length($alphabet) == $n);
        if (substr($alphabet, 0, $n) eq substr($std_alpha, 0, $n)) {
            $key = \%std_alpha_key;
        } else {
            $key = { };
            for (my $i = 0; $i < length($alphabet); ++$i) {
                my $c = substr($alphabet, $i, 1);
                croak "Character '$c' repeated in ALPHABET"
                    if (exists($key->{$c}));
                $key->{$c} = $i;
            }
        }
    }

    my $noutput = int((length($message) * lg($n)) / 8);

    my $x = new Math::BigInt();
    for (my $i = 0; $i < length($message); ++$i) {
        my $c = substr($message, $i, 1);
        return undef if (!exists($key->{$c}));
        $x->bmul($n);
        $x->badd($key->{$c});
    }

    my $res = '';
    for (my $i = 0; $i < $noutput; ++$i) {
        my ($quo, $rem) = $x->bdiv(256);
        $res .= pack('C', $rem);
    }

    return scalar(reverse($res));
}

my %fastblocksize;

# _blocksize N
# Return the block size for the pseudo-base-N encoding.
sub _blocksize ($) {
    my $n = shift;
    return $fastblocksize{$n} if (exists($fastblocksize{$n}));
    my $blocksize = 0;
    # Gah. Can't "use integer" because that gives *signed* 32-bit integers,
    # which isn't what we want!
    my $x = 0xffffffff;
    while ($x) {
        ++$blocksize;
        $x = int($x / $n);
    }
    $fastblocksize{$n} = $blocksize;
    return $blocksize;
}

=item encodefast N MESSAGE [ALPHABET]

Like encode, but instead of using true base-N encoding, instead use an analogue
of Adobe's "ASCII85" encoding, in which the MESSAGE is broken into 32-bit
chunks, and each of those is converted into base N. This avoids
arbitrary-precision arithmetic, and is therefore much faster than encode,
though incompatible and less parsimonious.

=cut
sub encodefast ($$;$) {
    my $n = shift;
    croak "N must be a positive integer" unless ($n =~ /^[1-9]\d*$/);
    my $message = shift;
    croak "MESSAGE may not be undef" unless (defined($message));
    my $alphabet = $std_alpha;
    if (@_) {
        $alphabet = shift;
        croak "ALPHABET may not be undef" unless (defined($alphabet));
        croak "ALPHABET must contain $n characters and a padding character"
            unless (length($alphabet) == $n + 1);
    } elsif ($n + 1 > length($alphabet)) {
        croak "not enough characters in standard alphabet -- supply your own";
    } else {
        $alphabet = substr($alphabet, 0, $n);
    }

    # Each four-byte block of MESSAGE is encoded as $blocksize symbols in
    # base N. We encode a three-byte block as $blocksize - 1 symbols, two-byte
    # as $blocksize - 2, etc.
    my $l = length($message);
    my $blocksize = _blocksize($n);

    my $res = '';
    for (my $i = 0; $i < $l; $i += 4) {
        my $nin = ($l - $i > 4) ? 4 : $l - $i;
        my $nout = $blocksize;
        my $val;
        if ($nin == 4) {
            $val = unpack('N', substr($message, $i, 4));
        } else {
            $val = 0;
            for (my $j = 0; $j < $nin; ++$j) {
                $val <<= 8;
                $val += unpack('C', substr($message, $i + $j, 1));
            }
            $nout -= (4 - $nin);
        }

        # this is nasty -- we'd like to "use integer" but we can't because we
        # can't then get unsigned semantics. So instead we cheat by using
        # floating-point arithmetic, and vaguely hope that it won't go horribly
        # wrong. Probably this should just be rewritten in a typed language.
        my $r = '';
        while ($val) {
            my $rem = $val % $n;
            $val = int($val / $n);
            $r .= substr($alphabet, $rem, 1);
        }

        # pad to block size.
        $r .= substr($alphabet, 0, 1) x ($nout - length($r))
            unless (length($r) == $nout);

        die "internal error; length of output block exceeds nout = $nout"
            if (length($r) > $nout);

        $res .= reverse($r);
    }

    return $res;
}

=item decodefast N MESSAGE [ALPHABET]

"Fast" analogue of decode; converse of encodefast.

=cut
sub decodefast ($$;$) {
    my $n = shift;
    croak "N must be a positive integer" unless ($n =~ /^[1-9]\d*$/);
    my $message = shift;
    croak "MESSAGE may not be undef" unless (defined($message));
    my $alphabet = $std_alpha;
    my $key = \%std_alpha_key;
    if (@_) {
        $alphabet = shift;
        croak "ALPHABET may not be undef" unless (defined($alphabet));
        croak "ALPHABET must contain $n characters"
            unless (length($alphabet) == $n);
        if (substr($alphabet, 0, $n) eq substr($std_alpha, 0, $n)) {
            $key = {%std_alpha_key};
        } else {
            $key = { };
            for (my $i = 0; $i < length($alphabet); ++$i) {
                my $c = substr($alphabet, $i, 1);
                croak "Character '$c' repeated in ALPHABET"
                    if (exists($key->{$c}));
                $key->{$c} = $i;
            }
        }
    }

    my $blocksize = _blocksize($n);

    my $res = '';
    my $l = length($message);
    for (my $i = 0; $i < $l; $i += $blocksize) {
        my $nin = ($l - $i > $blocksize) ? $blocksize : $l - $i;
        my $nout = 4;
        if ($nin < $blocksize) {
            $nout -= $blocksize - $nin;
            return undef if ($nout < 0);
        }

        my $val = 0;
        for (my $j = 0; $j < $nin; ++$j) {
            $val *= $n;
            my $c = substr($message, $i + $j, 1);
            return undef if (!exists($key->{$c}));
            $val += $key->{$c};
        }

        my $r = pack('N', $val);
        $r = substr($r, 4 - $nout, $nout) if ($nout < 4);

        $res .= $r;
    }

    return $res;
}

1;
