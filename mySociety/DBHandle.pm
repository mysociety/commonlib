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
# $Id: DBHandle.pm,v 1.10 2005-03-03 11:21:50 chris Exp $
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

port on which to contact database server.

=back

A key whose value is not defined is treated as if it were not present.

=cut
sub configure (%) {
    my %conf = @_;
    my %allowed = map { $_ => 1 } qw(Host Port Name User Password);
    foreach (keys %conf) {
        delete($conf{$_}) if (!defined($conf{$_}));
        die "Unknown key '$_' passed to configure" if (!exists($allowed{$_}));
    }
    foreach (qw(Name User)) {
        die "Required key '$_' missing in configure" if (!exists($conf{$_}));
    }
    $conf{Password} ||= undef;
    %mySociety::DBHandle::conf = %conf;
    $mySociety::DBHandle::conf_ok = 1;
}

=item new_dbh

Return a new handle open on the database.

=cut
sub new_dbh () {
    die "configure not yet called" unless ($mySociety::DBHandle::conf_ok);
    my $connstr = 'dbi:Pg:dbname=' . $mySociety::DBHandle::conf{Name};
    $connstr .= ";host=$mySociety::DBHandle::conf{Host}"
        if (exists($mySociety::DBHandle::conf{Host}));
    $connstr .= ";port=$mySociety::DBHandle::conf{Port}"
        if (exists($mySociety::DBHandle::conf{Port}));
    my $dbh = DBI->connect($connstr,
                        $mySociety::DBHandle::conf{User},
                        $mySociety::DBHandle::conf{Password}, {
                            RaiseError => 0,
                            AutoCommit => 0,
                            PrintError => 0,
                            PrintWarn => 0,
                            RaiseError => 1
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
    }
    return $dbh;
}

END {
    dbh()->disconnect();
}

1;
