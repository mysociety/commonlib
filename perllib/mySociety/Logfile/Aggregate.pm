#!/usr/bin/perl
#
# mySociety/Logfile/Aggregate.pm:
# Represent a set of logfiles.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: team@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Aggregate.pm,v 1.3 2009-01-26 14:21:55 matthew Exp $
#

package mySociety::Logfile::Aggregate;

use mySociety::Logfile;

=head1 NAME

mySociety::Logfile::Aggregate

=head1 DESCRIPTION

mySociety::Logfile class representing the union of a set of log files.

=head1 FUNCTIONS

=over 4

=cut

@mySociety::Logfile::Aggregate::ISA = qw(mySociety::Logfile);

# _update
# Update list of logfiles.
sub _update ($) {
    my ($self) = @_;
    my $N = 0;
    foreach my $n (glob($self->{glob})) {
        my $f = 0;
        if (!exists($self->{files}->{$n})) {
            $self->{files}->{$n}->{l} = "$self->{type}"->new($n);
            $f = 1;
        }
        
        if ($f || $self->{files}->{$n}->{generation} != $self->{files}->{$n}->{l}->generation()) {
            $self->{files}->{$n}->{begin} = $self->{files}->{$n}->{l}->time($self->{files}->{$n}->{l}->firstline());
            $self->{files}->{$n}->{generation} = $self->{files}->{$n}->{l}->generation();
            ++$N;
        }
    }

    if ($N > 0) {
        # Make a list of the logfile objects themselves.
        $self->{order} = [
                map { $self->{files}->{$_}->{l} }
                    sort { $self->{files}->{$a}->{begin} <=> $self->{files}->{$b}->{begin} }
                        keys %{$self->{files}}
            ];
        $self->{begin} = [
                map { $self->{files}->{$_}->{begin} }
                    sort { $self->{files}->{$a}->{begin} <=> $self->{files}->{$b}->{begin} }
                        keys %{$self->{files}}
            ];
        ++$self->{generation};
    }
}

=item new TYPE GLOB

Create a new aggregate logfile out of several real logfiles. GLOB specifies
the files which will be built into the aggregate; TYPE is the classname to use
to parse each individual logfile.

=cut
sub new ($$$) {
    my ($class, $type, $glob) = @_;
    my $self = { files => { }, type => $type, glob => $glob, generation => 0 };
    bless($self, $class);
    $self->_update();
    return $self;
}

sub getline ($$) {
    my ($self, $o) = @_;
    $self->_update();
    return $self->{order}->[$o->[0]]->getline($o->[1]);
}

sub firstline ($) {
    my ($self) = @_;
    return [ 0, $self->{order}->[0]->firstline() ];
}

sub lastline ($) {
    my ($self) = @_;
    return [ @{$self->{order}} - 1, $self->{order}->[-1]->lastline() ];
}

sub nextline ($$) {
    my ($self, $o) = @_;
    my $o2 = $self->{order}->[$o->[0]]->nextline($o->[1]);
    return [ $o->[0], $o2 ] if (defined($o2));
    ++$o->[0];
    return undef if ($o->[0] == @{$self->{order}});
    return [ $o->[0], $self->{order}->[$o->[0]]->firstline() ];
}

sub prevline ($$) {
    my ($self, $o) = @_;
    my $o2 = $self->{order}->[$o->[0]]->prevline($o->[1]);
    return [ $o->[0], $o2 ] if (defined($o2));
    --$o->[0];
    return undef if ($o->[0] < 0);
    return [ $o->[0], $self->{order}->[$o->[0]]->lastline() ];
}

sub parse ($$) {
    my ($self, $line) = @_;
    return $self->{order}->[0]->parse($line); # XXX assume that parsing depends only on contents of line
}

sub findtime ($$) {
    my ($self, $time) = @_;
    # Find the first logfile in which the right line could lie, then search
    # within it.
    my ($il, $ih) = (0, @{$self->{order}} - 1);

    my $tl = $self->{begin}->[$il];
    my $th = $self->{begin}->[$ih];

    my $o;
    if ($th < $time) {
        $o = [ $ih, $self->{order}->[$ih]->findtime($time) ];
        return defined($o->[1]) ? $o : undef;
    }
    
    while ($ih > $il + 1) {
        my $i = int(($il + $ih) / 2);
        my $t = $self->{begin}->[$i];
        if ($t > $time) {
            $ih = $i;
        } else {
            $il = $i;
        }
    }

    do {
        $o = [ $il, $self->{order}->[$il]->findtime($time) ];
        ++$il;
    } while ($il < @{$self->{order}} && !defined($o->[1]));

    return defined($o->[1]) ? $o : undef;
}

1;
