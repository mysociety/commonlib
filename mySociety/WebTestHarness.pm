#!/usr/bin/perl
#
# mySociety/WebTestHarness.pm;
# Used for testing websites.  Can do the following:
# - Rebuild a database with given schema (database_drop_reload)
# - Some extentions to WWW::Mechanize (browser_* functions)
# - Watch HTTP logs files for new errors (log_watcher_* functions)
# - Store email in db and check it (email_* functions)
# - Check PHP syntax for given files (php_check_syntax)
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: WebTestHarness.pm,v 1.6 2005-03-23 17:24:12 francis Exp $
#

package mySociety::WebTestHarness;

use File::Find;
use File::Slurp;
use WWW::Mechanize;

use mySociety::Logfile;
use mySociety::DBHandle qw(dbh);

############################################################################
# Constructor

=item new DB_OPTION_PREFIX SCHEMA

Create a new test harness object.  DB_OPTION_PREFIX is the prefix
of the mySociety configuration parameters for the database being
used. e.g. PB_ for PB_DB_NAME.  SCHEMA is the database schema file.

=cut
sub new ($$) {
    my ($class, $db_option_prefix) = @_;
    my $self = {};

    $self->{useragent} = new WWW::Mechanize(autocheck => 1);

    $self->{dbhost} = mySociety::Config::get($db_option_prefix.'DB_HOST', undef);
    $self->{dbport} = mySociety::Config::get($db_option_prefix.'DB_PORT', undef);
    $self->{dbname}  = mySociety::Config::get($db_option_prefix.'DB_NAME');
    $self->{dbuser} = mySociety::Config::get($db_option_prefix.'DB_USER');
    $self->{dbpass} = mySociety::Config::get($db_option_prefix.'DB_PASS');

    mySociety::DBHandle::configure(Name => $self->{dbname}, 
            User => $self->{dbuser}, Password => $self->{dbpass},
            Host => $self->{dbhost}, Port => $self->{dbport});

    return bless($self, $class);
}

=item database_drop_reload SCHEMA_FILE

Drops the database, and reloads it from the given schema.  Checks the database
has _testharness in its name to avoid clobbering something important.

=cut
sub database_drop_reload ($$)
{
    my ($self, $schema_file) = @_;

    # Drop and recreate database from schema
    die "Database will be dropped, so for safety must be called '_testharness'" if ($self->{dbname} !~ m/_testharness$/);

    # ... make connection with no database name and drop and remake database
    my $connstr = 'dbi:Pg:';
    $connstr .= "host=".$self->{dbhost}.";" if ($self->{dbhost});
    $connstr .= "port=".$self->{dbport}.";" if ($self->{dbport});
    my $db_remake_db = DBI->connect($connstr, undef, $self->{dbpass}, {
                            RaiseError => 1, AutoCommit => 1, PrintError => 0, PrintWarn => 1, });
    $db_remake_db->do("drop database " . $self->{dbname});
    $db_remake_db->do("create database " . $self->{dbname});
    $db_remake_db->disconnect();

    # ... load in schema
    $schema = read_file($schema_file);
    dbh()->do($schema);
    dbh()->commit();
}

############################################################################
# Browser, user agent

=item browser_get_agent

Returns an instance of WWW::Mechanize.

=cut
sub browser_get_agent ($) {
    my ($self) = @_;
    return $self->{useragent};
}

=item browser_check_contents STRING

Checks the current page which is being browsed contains
the given string.

=cut
sub browser_check_contents ($$) {
    my ($self, $check) = @_;
    if ($self->{useragent}->content !~ m/$check/) {
        print $self->{useragent}->content;
        print "\n\n";
        die "URL " . $self->{useragent}->uri() . " does not contain '" . $check . "'";
    }
}

=item browser_check_no_contents STRING

Checks the current page which is being browsed does not contain the given
string.

=cut
sub browser_check_no_contents ($$) {
    my ($self, $check) = @_;
    if ($self->{useragent}->content =~ m/$check/) {
        print $self->{useragent}->content;
        print "\n\n";
        die "URL " . $self->{useragent}->uri() . " unexpectedly contains '" . $check . "'";
    }
}


############################################################################
# Log watcher

=item log_watcher_setup LOG_FILENAME

Configures test harness to watch an HTTP error log file.

=cut
sub log_watcher_setup ($$) {
    my ($self, $file) = @_;

    $self->{http_logobj} = new mySociety::Logfile($file);
    $self->{http_logoffset} = $self->{http_logobj}->lastline();

}

=item log_watcher_get_errors

Returns error text if there are new errors since last call, or empty string
(which is false) otherwise.

=cut 
sub log_watcher_get_errors ($) {
    my ($self) = @_;
    my $error = "";
    $self->{http_logobj}->_update();
    while ($self->{http_logobj}->nextline($self->{http_logoffset})) {
        $self->{http_logoffset} = $self->{http_logobj}->nextline($self->{http_logoffset});
        $error .= $self->{http_logobj}->getline($self->{http_logoffset}) . "\n";
    }
    return $error;
}

=item log_watcher_check

"die"s if there have been any HTTP log file errors since last call to either
this function or to log_watcher_get_errors.

=cut
sub log_watcher_check($) {     
    my ($self) = @_;
    my $errors = $self->log_watcher_get_errors();
    die $errors if ($errors);
}

############################################################################
# Email

=item email_setup

Prepares for incoming email.

=cut

sub email_setup($) {
    my ($self) = @_;
    dbh()->do("create table testharness_mail (
      id serial not null primary key,
      content text not null default '')");
    dbh()->commit();
}

=item email_get_containing STRING

Returns the email containing the given STRING as an SQL expression.  i.e. Use %
for wildcard.  It is an error if no matching mails are found within a few
seconds, or there is more than one match.

=cut
sub email_get_containing($$) {
    my ($self, $check) = @_;
    my $mails;
    my $got = 0;
    my $c = 0;
    while ($got == 0) {
        $mails = dbh()->selectall_arrayref("select id, content from testharness_mail
            where content like ?", {}, $check);
        $got = scalar @$mails;
        die "Email containing '$check' not found even after $c sec wait" if ($got == 0 && $c > 10);
        die "Too many emails found containing '$check'" if ($got > 1);
        $c++;
        sleep 1;
    }
    my ($id, $content) = @{$mails->[0]};
    dbh()->do("delete from testharness_mail where id = ?", {}, $id);
    dbh()->commit();
    return $content;
}

=item email_check_none_left

Throws an error if there are any emails left.

=cut

sub email_check_none_left($) {
    my ($self) = @_;

    sleep 5;
    my $emails_left = dbh()->selectrow_array("select count(*) from testharness_mail");
    die "$emails_left unexpected emails left at the end" if $emails_left > 0;
}

=item email_incoming MAIL_BODY

Call when a new email arrives, and it will be stored for access via
email_get_containing.

=cut
sub email_incoming($$) {
    my ($self, $content) = @_;
    dbh()->do("insert into testharness_mail (content) values (?)", {}, $content);
    dbh()->commit();

}

############################################################################
# PHP functions

=item php_check_syntax DIRECTORY [EXTENSION]

Recursively checks files in the directory have valid syntax.  EXTENSION
is a regular expression, and defaults to qr/\.php$/.

=cut
sub php_check_syntax($$;$) {
    my ($self, $dir, $extension) = @_;
    $extension = qr/\.php$/ unless $extension;
    my $do_php_check_syntax = sub {
        if (m/$extension/) {
            my $phpbin = mySociety::Config::find_php();
            my $syntax_result = qx#$phpbin -l $_#;
            die $syntax_result if ($syntax_result ne "No syntax errors detected in $_\n");
        }
    };
    find($do_php_check_syntax, $dir);
}


############################################################################

1;
