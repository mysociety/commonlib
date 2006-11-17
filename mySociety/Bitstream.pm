#!/usr/bin/perl
#
# mySociety/Bitstream.pm:
# Arbitrary bitstreams.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Bitstream.pm,v 1.1 2006-11-17 17:44:05 chris Exp $
#

package mySociety::Bitstream;

use strict;

# Implement as a stream of bytes because that's easier. We don't need to be
# efficient for the applications I'm currently envisaging. ->{length} is the
# number of bits available, and ->{cursor} the position in the stream where
# we read/write. The buffer is treated as being in network order.
use fields qw(buffer length cursor);

use Carp;
use Fcntl qw(:seek);

=item new [BUFFER [LENGTH]]

Create a new bitstream from BUFFER (string or reference to string); if BUFFER
is not specified an empty bitstream is created. If LENGTH is specified, then
assume that BUFFER contains LENGTH bits, rather than the number of bytes in
BUFFER multiplied by eight.

=cut
sub new ($$) {
    my mySociety::Bitstream $self = shift;
    my $buffer;
    my $length;

    $self = fields::new($self)
        unless (ref($self));
    
    if (@_) {
        $buffer = shift;
        if (@_) {
            $length = shift;
            croak "LENGTH must be a nonnegative number of bits"
                unless ($length =~ /^(0|[1-9]\d*)$/);
        }
    } else {
        my $x = "";
        $buffer = \$x;
        $length = 0;
    }

    if (!ref($buffer)) {
        $buffer = \$buffer;
    } elsif (ref($buffer) ne 'SCALAR') {
        croak "BUFFER must be scalar or reference to scalar, not reference to "
                . ref($buffer);
    }

    $length = CORE::length($$buffer) * 8 if (!defined($length));

    $self->{buffer} = $buffer;
    $self->{length} = $length;
    $self->{cursor} = 0;

    return $self;
}

=item seek AMOUNT SENSE

Seek AMOUNT in SENSE. SENSE should be SEEK_SET, SEEK_CUR or SEEK_END; returns
the new absolute position on success, or undef on failure (if you attempt to
seek to before the beginning or off the end; or if SENSE is invalid).

=cut
sub seek ($$$) {
    my mySociety::Bitstream $self = shift;
    my ($pos, $sense) = @_;
    
    croak "POS must be an integer"
        unless (defined($pos) && $pos =~ /^[+-]?(0|[1-9]\d*)$/);
    croak "SENSE must be specified"
        unless (defined($sense));
    
    my $newpos;
    if ($sense == SEEK_SET) {
        $newpos = $pos;
    } elsif ($sense == SEEK_CUR) {
        $newpos = $self->{cursor} + $pos;
    } elsif ($sense == SEEK_END) {
        $newpos = $self->{length} + $pos;
    } else {
        return undef;
    }

    if ($newpos < 0 || $newpos > $self->{length}) {
        return undef;
    } else {
        $self->{cursor} = $newpos;
        return $newpos;
    }
}

=item rewind

Equivalent to ->seek(0, SEEK_SET).

=cut
sub rewind ($) {
    my mySociety::Bitstream $self = shift;
    return $self->seek(0, SEEK_SET);
}

=item tell

Return the current position in the stream.

=cut
sub tell ($) {
    my mySociety::Bitstream $self = shift;
    return $self->{cursor};
}

=item length

Return the number of bits in the stream.

=cut
sub length ($) {
    my mySociety::Bitstream $self = shift;
    return $self->{length};
}

sub bytepos ($) {
    return int($_[0] / 8);
}

=item write VALUE LENGTH

Write LENGTH bits from VALUE to the stream. VALUE should be an integer, and its
lowest LENGTH bits are used. Returns true on success or false on failure.

=cut
sub write ($$$) {
    my mySociety::Bitstream $self = shift;
    my ($value, $length) = @_;
    croak "VALUE must be a nonnegative integer"
        unless (defined($value) && $value =~ /^(0|[1-9]\d*)$/);
    croak "LENGTH must be a nonnegative integer"
        unless (defined($length) && $length =~ /^(0|[1-9]\d*)$/);

    return 1 if ($length == 0);

    my $buf = $self->{buffer};

    my $i = bytepos($self->{cursor});
    my $offset = $self->{cursor} - $i * 8;      # position within byte
    my $n = 0;                                  # bit offset in value
    while ($n < $length) {
        # how many bits fit in this byte
        my $nbits = (8 - $offset);
        $nbits = ($length - $n) if ($nbits > ($length - $n));
        # the part of the value we write in
        my $bits = $value >> (($length - $n) - (8 - $offset));
        # the bits we write to.
        my $mask = (0xff ^ (0xff >> $nbits)) >> $offset;

        my $nv = ($value >> ($length - $n - $nbits)) & ((1 << $nbits) - 1);

        $$buf .= "\0" if ($i >= CORE::length($$buf));

        substr($$buf, $i, 1)
            = pack('C', (~$mask & unpack('C', substr($$buf, $i, 1)))
                        | ($nv << (8 - $nbits - $offset)));

        $offset = 0;
        ++$i;
        $n += $nbits;
    }

    $self->{length} = $self->{cursor} + $length
        if ($self->{cursor} + $length > $self->{length});
    $self->{cursor} += $length;

    return 1;
}

=item read LENGTH

Read LENGTH bits from the stream, returning them as an integer. Returns undef
if there are not enough bits in the stream to return LENGTH of them.

=cut
sub read ($$) {
    my mySociety::Bitstream $self = shift;
    my $length = shift;
    croak "LENGTH must be a nonnegative integer"
        unless (defined($length) && $length =~ /^(0|[1-9]\d*)$/);

    return undef if ($self->{cursor} + $length > $self->{length});

    return 0 if ($length == 0);

    my $value = 0;

    my $buf = $self->{buffer};

    my $i = bytepos($self->{cursor});
    my $offset = $self->{cursor} - $i * 8;
    my $n = 0;
    while ($n < $length) {
        my $nbits = (8 - $offset);
        $nbits = ($length - $n) if ($nbits > ($length - $n));
        my $mask = (0xff ^ (0xff >> $nbits)) >> $offset;

        $value |= ((unpack('C', substr($$buf, $i, 1)) & $mask)
                    >> (8 - $nbits - $offset)
                    << ($length - $n - $nbits));

        $offset = 0;
        ++$i;
        $n += $nbits;
    }

    $self->{cursor} += $length;

    return $value;
}

1;
