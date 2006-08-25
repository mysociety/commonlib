#!/usr/bin/perl
#
# mySociety/DBHandle.pm:
# Abstraction of database handle utilities.
#
# This package maintains a global configuration for talking to a single
# database.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: DBHandle.pm,v 1.16 2006-08-25 13:13:23 chris Exp $
#

package mySociety::DBHandle::Error;

use Error;

@mySociety::DBHandle::Error::ISA = qw(Error::Simple);

package mySociety::DBHandle;

use strict;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&dbh &new_dbh);
}

use Carp;
use DBD::Pg;
use DBI;
use Error qw(:try);

$mySociety::DBHandle::conf_ok = 0;
%mySociety::DBHandle::conf = ( );

=head1 NAME

mySociety::DBHandle

=head1 DESCRIPTION

Common functionality for shared database handles.

=head1 FUNCTIONS

=over 4

=item configure KEY VALUE ...

Configure database access. Must be called before dbh() or newdbh(). Allowed
keys are,

=over 4

=item Name

database name (required);

=item User

Database username (required);

=item Password

database password;

=item Host

host on which to contact database server;

=item Port

port on which to contact database server;

=item OnFirstUse

reference to code to be executed after the first connection to the database is
made.

=back

A key whose value is not defined is treated as if it were not present.

=cut
sub configure (%) {
warn "in configure in $$\n";
    my %conf = @_;
    my %allowed = map { $_ => 1 } qw(Host Port Name User Password OnFirstUse);
    foreach (keys %conf) {
        delete($conf{$_}) if (!defined($conf{$_}));
        croak "Unknown key '$_' passed to configure" if (!exists($allowed{$_}));
    }
    foreach (qw(Name User)) {
        croak "Required key '$_' missing in configure" if (!exists($conf{$_}));
    }
    $conf{Password} ||= undef;
    %mySociety::DBHandle::conf = %conf;
    $mySociety::DBHandle::conf_ok = 1;
warn "conf_ok in $$";
}

=item new_dbh

Return a new handle open on the database.

=cut
sub new_dbh () {
    croak "configure not yet called in $$" unless ($mySociety::DBHandle::conf_ok);
    my $connstr = 'dbi:Pg:dbname=' . $mySociety::DBHandle::conf{Name};
    $connstr .= ";host=$mySociety::DBHandle::conf{Host}"
        if (exists($mySociety::DBHandle::conf{Host}));
    $connstr .= ";port=$mySociety::DBHandle::conf{Port}"
        if (exists($mySociety::DBHandle::conf{Port}));
    $connstr .= ";sslmode=allow";
    my $dbh = DBI->connect($connstr,
                        $mySociety::DBHandle::conf{User},
                        $mySociety::DBHandle::conf{Password}, {
                            AutoCommit => 0,
                            PrintError => 0,
                            PrintWarn => 0,
                            RaiseError => 1,
                            # This sets the UTF-8 flag on strings returned from
                            # Postgres, which is appropriate since we store all
                            # data in the database as UTF-8. Why this is needed
                            # I have no idea, given that the database has an
                            # encoding which should be set to "UNICODE". Just
                            # another day in character-sets trainwreck land,
                            # I suppose.
                            pg_enable_utf8 => 1
                        });
    $dbh->{HandleError} =
        sub ($$$) {
            my ($err) = @_;
            # Let's not make any unwise assumptions about reentrancy here.
            local $dbh->{HandleError} = sub ($$$) { };
            $dbh->rollback();
            throw mySociety::DBHandle::Error($err);
        };
    $dbh->{RaiseError} = 0;
    return $dbh;
}

=item dbh

Return a shared database handle.

=cut
sub dbh () {
    our $dbh;
    our $dbh_process;

    # If the connection to the database has gone away, try to detect the
    # condition here. Also detect a fork which has occured since dbh() was last
    # called. XXX this means we could restart a transaction half-way through. 
    if (!defined($dbh) || $dbh_process != $$
        || !eval { $dbh->ping() }) { # call through eval because that's what Apache::DBI does
        $dbh->{InactiveDestroy} = 1 if (defined($dbh));
        $dbh = new_dbh();
        $dbh_process = $$;
        if (exists($mySociety::DBHandle::conf{OnFirstUse})) {
            my $f = $mySociety::DBHandle::conf{OnFirstUse};
            delete $mySociety::DBHandle::conf{OnFirstUse};
            &$f();
        }
    }
    return $dbh;
}

=item disconnect

Disconnect shared handle.

=cut

sub disconnect () {
    our $dbh;
    if (defined($dbh)) {
        $dbh->disconnect();
        $dbh = undef;
    }
}

END {
    our $dbh;
    $dbh->disconnect() if (defined($dbh));
}

1;
