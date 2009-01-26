#!/usr/bin/perl
#
# mySociety/PIDFile.pm:
# Implementation of locked PID files.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: team@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: PIDFile.pm,v 1.4 2009-01-26 14:21:52 matthew Exp $
#

package mySociety::PIDFile::Error;

@mySociety::PIDFile::Error::ISA = qw(Error::Simple);

package mySociety::PIDFile;

use strict;

use Error qw(:try);
use Fcntl qw(:flock);
use IO::File;

=item new FILE

Attempt to create and lock the named PID FILE. Throws an exception of type
mySociety::PIDFile::Error on failure, with a descriptive message. Otherwise
the returned object should be held in scope for the whole of the code which
the PID file should protect. Undef the object returned or call the DESTROY
explicitly to delete and close the PID file.

=cut
sub new ($$) {
    my ($class, $name) = @_;
    my $ret = undef;

    my $h = new IO::File("$name", O_RDWR | O_CREAT, 0600);
    throw mySociety::PIDFile::Error("$name: $!") if (!$h);

    try {
        # Now attempt to lock the file.
        if (!flock($h, LOCK_EX | LOCK_NB)) {
            # Another process holds the lock.
            my $pid = $h->getline() or return undef;
            chomp($pid);
            if ($pid =~ /^\d+$/ and kill(0, $pid)) {
                throw mySociety::PIDFile::Error("$name: already held by PID $pid");
            } else {
                throw mySociety::PIDFile::Error("$name: locked, but contains \"$pid\", not a PID");
            }
        } else {
            if (!$h->truncate(0)
                || !$h->seek(0, SEEK_SET)
                || !$h->print("$$\n")
                || !$h->flush()) {
                throw mySociety::PIDFile::Error("$name: $!");
            }
        }
    } catch Error with {
        my $E = shift;
        $h->close() if ($h);
        $E->throw();
    };

    return bless({ name => $name, h => $h, pid => $$ }, $class);
}

=item DESTROY

Close and delete the PID file on exit.

=cut
sub DESTROY ($) {
    my ($self) = @_;
    # Only the process which created the PID file should remove it.
    unlink($self->{name}) if ($self->{pid} == $$);
    $self->{h}->close();
}

1;
