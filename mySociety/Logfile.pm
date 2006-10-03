#!/usr/bin/perl
#
# mySociety/Logfile.pm:
# Logfile reading/searching stuff.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Logfile.pm,v 1.9 2006-10-03 14:47:46 francis Exp $
#

package mySociety::Logfile::Error;

use Error;

@mySociety::Logfile::Error::ISA = qw(Error::Simple);

package mySociety::Logfile;

use Error qw(:try);
use File::stat;
use IO::File;
use POSIX ();
use Sys::Mmap;
use Time::HiRes;

=head1 NAME

mySociety::Logfile

=head1 DESCRIPTION

Object representing the contents of a logfile; that is, a file which contains
a list of diagnostic messages in chronological order.

package mySociety::Logfile;

=head1 FUNCTIONS

=over 4

=cut

# maplen SIZE
# Return the length of a mapping which should be used to cover a file of SIZE
# bytes.
sub maplen ($) {
    my ($size) = @_;
    use integer;
    my $pagesize = POSIX::sysconf(&POSIX::_SC_PAGESIZE);
    my $maplen = (($size + $pagesize - 1) / $pagesize) * $pagesize;

    # from Sys::Mmap(3pm), help for mmap: "The LENGTH argument can be zero in
    # which case a stat is done on FILEHANDLE and the size of the underlying
    # file is used instead." Which for some reason causes an "invalid argument"
    # error from mmap in our case. 
    # In contrast, dpkg's 1.13.8 changelog entry says:
    # "Linux 2.6.12 changed the behaviour of mmap to fail and set EINVAL when
    # given a zero length, rather than returning NULL.  This is POSIXly
    # correct, so handle zero-length package control files (like available)."
    throw mySociety::Logfile::Error("Zero length log file not supported") if $maplen == 0;
    return $maplen == 0 ? $pagesize : $maplen;
}

# _update
# Update the mapping for the logfile, if it has changed on disk.
sub _update ($) {
    my ($self) = @_;
    my $st = stat($self->{fh})
        or throw mySociety::Logfile::Error("$self->{file}: $!");

    if ($st->size() != $self->{st}->size()) {
        # Accept the file shrinking, though that's likely to cause trouble
        # later.
        munmap($self->{mapping});
        mmap($self->{mapping}, maplen($st->size()), PROT_READ, MAP_SHARED, $self->{fh}, 0)
            or throw mySociety::Logfile::Error("$self->{file}: $!");
        ++$self->{generation};
    }

    $self->{st} = $st;
    $self->{when} = Time::HiRes::time();
}

=item new FILENAME

Create a new logfile object representing the contents of FILENAME.

=cut
@mySociety::Logfile::fields = ( text => 'Message' );
sub new ($$) {
    my ($class, $file) = @_;
    my $self = { file => $file, fields => \@mySociety::Logfile::fields, mapping => undef, generation => 0 };
    try {
        throw mySociety::Logfile::Error("$file IO::File failed: $!") if !($self->{fh} = new IO::File($file, O_RDONLY));
        throw mySociety::Logfile::Error("$file stat failed: $!") if !($self->{st} = stat($self->{fh}));
        throw mySociety::Logfile::Error("$file mmap failed: $!") 
            if !mmap($self->{mapping}, maplen($self->{st}->size()), PROT_READ, MAP_SHARED, $self->{fh}, 0);
        $self->{when} = Time::HiRes::time();

        # Determine line-ending type to use based on the contents of the first
        # 8KB of the file.
        if (substr($self->{mapping}, 0, $self->{st}->size > 8192 ? 8192 : $self->{st}->size) =~ m#[^\r]\n#s) {
            $self->{lineending} = "\n";
        } else {
            $self->{lineending} = "\r\n";
        }
    } otherwise {
        my $E = shift;
        munmap($self->{mapping}) if ($self->{mapping});
        $self->{fh}->close() if ($self->{fh});
        throw $E;
    };

    return bless($self, $class);
}

# DESTROY
# Destructor: unmap and close file.
sub DESTROY ($) {
    my ($self) = @_;
    munmap($self->{mapping}) if (defined($self->{mapping}));
    $self->{fh}->close() if (defined($self->{fh}));
}

=item generation

Returns the "generation number"; this changes whenever the underlying contents
of the logfile change.

=cut
sub generation ($) {
    return $_[0]->{generation};
}

# _normalise OFFSET
# Give the smallest offset which identifies the same line as OFFSET.
sub _normalise ($$) {
    my ($self, $offset) = @_;
    if ($offset == 0) {
        return 0;
    } else {
        my $i = rindex($self->{mapping}, $self->{lineending}, $offset - 1);
        if ($i == -1) {
            return 0;
        } else {
            return $i + length($self->{lineending});
        }
    }
}

=item getline OFFSET

Return the log file line within which OFFSET lies, or undef if OFFSET is out of
range.

=cut
sub getline ($$) {
    my ($self, $offset) = @_;
    $self->_update() if (Time::HiRes::time() > $self->{when} + 1.);
    die "OFFSET must be a nonnegative integer" unless (defined($offset) && $offset =~ m#^\+?\d+$#);
    return undef if ($offset > $self->{st}->size());
    my $i = $self->_normalise($offset);
    my $j = index($self->{mapping}, $self->{lineending}, $offset);
    $j = $self->{st}->size() - 1 if ($j == -1);
    return substr($self->{mapping}, $i, $j - $i);
}

=item nextline OFFSET

Returns the offset of the next line after OFFSET, or undef if there is none.

=cut
sub nextline ($$) {
    my ($self, $offset) = @_;
    die "OFFSET must be a nonnegative integer" unless ($offset =~ m#^\+?\d+$#);
    my $i = index($self->{mapping}, $self->{lineending}, $offset);
    return undef if ($i == -1);
    $i += length($self->{lineending});
    return undef if ($i >= $self->{st}->size());
    return $i;
}

=item prevline OFFSET

Returns the offset of the next line after OFFSET, or undef if there is none.

=cut
sub prevline ($$) {
    my ($self, $offset) = @_;
    die "OFFSET must be a nonnegative integer" unless ($offset =~ m#^\+?\d+$#);
    my $i = rindex($self->{mapping}, $self->{lineending}, $offset - 1);
    return undef if ($i == -1);
    return $i;
}

=item firstline

Return an offset specifying the first line in the file.

=cut
sub firstline ($) {
    return 0;
}

=item lastline

Return an offset specifying the last line in the file.

=cut
sub lastline ($) {
    my ($self) = @_;
    return $self->_normalise($self->{st}->size() - 1);
}

=item parse LINE

Parse the log LINE to extract its constituent fields.

=cut
sub parse ($$) {
    my ($self, $line) = @_;
    return { text => $line };   # No parsing in base class
}

=item fields [FIELD]

Return a reference to a list of fields and their descriptions; or, if FIELD is
specified, return the description of that field, or undef if there is no such
field.

=cut
sub fields ($;$) {
    my ($self, $field) = @_;
    if ($field) {
        my $f = { @{$self->{fields}} };
        return $f->{$field} if (exists($f->{$field}));
        return undef;
    } else {
        return @{$self->{fields}};
    }
}

# _time OFFSET
# Return time at OFFSET, if present, otherwise undef.
sub _time ($$) {
    my ($self, $offset) = @_;
    return $self->parse($self->getline($offset))->{time};
}

=item time OFFSET

Return the time of the line at OFFSET. If there is no time at OFFSET, estimate
a suitable time based on surrounding lines. Returns undef if no time could be
found or if OFFSET is out of range.

=cut
sub time ($$) {
    my ($self, $offset) = @_;
    my $time = $self->_time($offset);
    return $time if (defined($time));
    
    # Otherwise we need to search outwards from this time.
    my ($il, $ih);
    my ($tl, $th);
    $il = $ih = $offset;
    do {
        $il = $self->prevline($il) if (defined($il));
        $ih = $self->nextline($ih) if (defined($ih));
        $il = undef if (defined($tl = $self->_time($il)));
        $ih = undef if (defined($th = $self->_time($ih)));
    } while (defined($il) || defined($ih));

    if ($tl and $th) {
        my $d = $th - $tl;
        return $tl + $d * 0.5;
    } elsif ($tl) {
        return $tl;
    } else {
        return $th;
    }
}

=item findtime TIME

Return an offset for the first message which is at or after TIME.

=cut
sub findtime ($$) {
    my ($self, $time) = @_;

    my $il = $self->firstline();
    my $ih = $self->lastline();
    my $tl = $self->time($il);
    my $th = $self->time($ih);

    if ($th == $time) {
        return $ih;
    } elsif ($th < $time) {
        return undef;
    }

    while ($il != $ih and $self->nextline($il) != $ih) {
        my $i = $self->_normalise(int(($il + $ih) / 2));
        $i = $self->nextline($i) if ($i == $il);
        my $t = $self->time($i);
        
        if ($t <= $time) {
            $il = $i;
            $tl = $t;
        } else {
            $ih = $i;
            $th = $t;
        }

        if ($tl eq $time) {
            return $il;
        }
    }

    return $il;
}

1;
