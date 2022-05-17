#!/usr/bin/perl
#
# mySociety/DBHandle.pm:
# Abstraction of database handle utilities.
#
# This package maintains a global configuration for talking to a single
# database.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org/

package mySociety::DBHandle::Error;

use Error;

@mySociety::DBHandle::Error::ISA = qw(Error::Simple);

package mySociety::DBHandle;

use strict;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&dbh &new_dbh &select_all &dbh_test);
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

Configure database access. Must be called before dbh() or new_dbh(). Allowed
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

=item DbType

database server to contact (defaults to Postgres);

=back

A key whose value is not defined is treated as if it were not present.

=cut
sub configure (%) {
    my %conf = @_;
    my %allowed = map { $_ => 1 } qw(Host Port Name User Password OnFirstUse DbType);
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
}

=item new_dbh

Return a new handle open on the database.

=cut
sub new_dbh () {
    croak "configure not yet called in new_dbh (pid: $$)" unless ($mySociety::DBHandle::conf_ok);
    my $connstr;
    if (exists($mySociety::DBHandle::conf{DbType})){
        $connstr = 'dbi:' . $mySociety::DBHandle::conf{DbType} . ':dbname=' . $mySociety::DBHandle::conf{Name};
    }else{
        $connstr = 'dbi:Pg:dbname=' . $mySociety::DBHandle::conf{Name};
    }
    $connstr .= ";host=$mySociety::DBHandle::conf{Host}"
        if (exists($mySociety::DBHandle::conf{Host}));
    $connstr .= ";port=$mySociety::DBHandle::conf{Port}"
        if (exists($mySociety::DBHandle::conf{Port}));
    $connstr .= ";sslmode=prefer";
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
                            pg_enable_utf8 => 1,
                            mysql_enable_utf8 => 1
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

=item dbh_test

Check database handle is okay, and create a new one if not.
Returns handle and process ID.

=cut

sub dbh_test($;$) {
    my ($handle, $pid) = @_;

    # If the connection to the database has gone away, try to detect the
    # condition here. Also detect a fork which has occured since last called.
    # XXX this means we could restart a transaction half-way through.
    if (!defined($handle) || ($pid && $pid != $$)
        || !eval { $handle->ping() }) { # call through eval because that's what Apache::DBI does
        $handle->{InactiveDestroy} = 1 if (defined($handle));
        $handle = new_dbh();
        $pid = $$;
        if (exists($mySociety::DBHandle::conf{OnFirstUse})) {
            my $f = $mySociety::DBHandle::conf{OnFirstUse};
            delete $mySociety::DBHandle::conf{OnFirstUse};
            &$f();
        }
    }
    return ($handle, $pid);
}

=item dbh

Return a database handle shared by calls to this function.

=cut
sub dbh () {
    our $dbh;
    our $dbh_process;
    ($dbh, $dbh_process) = dbh_test($dbh, $dbh_process);
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

sub select_all {
    my ($query, @bind_values) = @_;
    my $dbh = dbh();
    local $dbh->{HandleError} =
        sub ($$$) {
            my ($err) = @_;
            # Let's not make any unwise assumptions about reentrancy here.
            local $dbh->{HandleError} = sub ($$$) { };
            $dbh->rollback();
            throw mySociety::DBHandle::Error($err . ": '" . $query . "' - args '" . join("','", @bind_values) . "'");
        };
    $dbh->selectall_arrayref($query, { Slice => {} }, @bind_values);
}

1;
