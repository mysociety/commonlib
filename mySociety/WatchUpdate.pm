#!/usr/bin/perl
#
# mySociety/WatchUpdate.pm:
# Object for watching for changes to a script.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: WatchUpdate.pm,v 1.1 2004-10-14 16:06:48 chris Exp $
#

package mySociety::WatchUpdate;

use File::stat;

=head1 NAME

mySociety::WatchUpdate

=head1 SYNOPSIS

    my $W = new mySociety::WatchUpdate();

    while (my $q = new CGI::Fast()) { # or whatever
        # process request
        #   ...

        $W->reexec_if_changed();
    }

=head1 DESCRIPTION

Watch for changes in the script or included modules, and re-exec if any occur.
Intended for use while debugging long-lived processes such as FastCGI scripts.

=head1 FUNCTIONS

=over 4

=item new

I<Class method.> Construct a new watching object.

=cut
sub new ($) {
    my ($class) = @_;
    my $self = { };
    bless($self, $class);
    $self->changed();
    return $self;
}

=item changed

I<Instance method.> Check whether any changes have taken place. Returns true if
they have, or false otherwise.

=cut
sub changed ($) {
    my ($self) = @_;
    foreach (($0, values %INC)) {
        my $s = stat($_);
        if (exists($self->{size}->{$_}) and exists($self->{time}->{$_})) {
            return 1 if ($s->size() != $self->{size}->{$_} or $s->mtime() != $self->{time}->{$_});
        }

        $self->{size}->{$_} = $s->size();
        $self->{time}->{$_} = $s->mtime();
    }
    return 0;
}

=item reexec_if_changed

I<Instance method.> Check whether any file changes have taken place and, if they
have, re-exec the script.

=cut
sub reexec_if_changed ($) {
    my ($self) = @_;
    exec($0, @ARGV) if ($self->changed());
}

1;
