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
# $Id: WebTestHarness.pm,v 1.19 2005-06-24 19:17:46 francis Exp $
#

package mySociety::WebTestHarness;

use File::Find;
use File::Slurp;
use File::Temp;
use WWW::Mechanize;
use Data::Dumper;

use mySociety::Logfile;
use mySociety::DBHandle qw(dbh);

############################################################################
# Constructor

=item new DB_OPTION_PREFIX SCHEMA

Create a new test harness object.  PARAMS is a hash ref containing:

db_option_prefix - The prefix of the mySociety configuration parameters for the
database being used. e.g. PB_ for PB_DB_NAME.  SCHEMA is the database schema
file.  Compulsory.

=cut
sub new ($$) {
    my ($class, $params) = @_;
    my $self = {};

    $self->{tempdir} = File::Temp::tempdir( CLEANUP => 0 );
    $self->{useragent} = new WWW::Mechanize(autocheck => 1);

    my $db_option_prefix = $params->{db_option_prefix};
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

If you get "NOTICE:  CREATE TABLE will create implicit sequence" messages
and would like to supress them, edit /etc/postgresql/postgresql.conf, setting
    client_min_messages = warning 

=cut
sub database_drop_reload ($$)
{
    my ($self, $schema_file) = @_;

    # Drop and recreate database from schema
    die "Database will be dropped, so for safety must have name starting '_testharness'" if ($self->{dbname} !~ m/_testharness$/);

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
    $self->database_load_schema($schema_file);
}

=item database_load_schema SCHEMA_FILE

Loads schema file into main database.

=cut
sub database_load_schema ($$) {
    my ($self, $schema_file) = @_;

    $schema = read_file($schema_file);
    dbh()->do($schema);
    dbh()->commit();
}

=item database_cycle_sequences NUMBER

Advances all user sequences in the database, such that
their next values are spaced apart by NUMBER values.  This
ensures that allocated ids will differ between different types,
so detecting bugs when the wrong id is used

=cut
sub database_cycle_sequences ($) {
    my ($self, $number) = @_;

    my $seqs = dbh()->selectcol_arrayref("select relname from pg_statio_user_sequences");

    my $start = 10;
    foreach $seq (@$seqs) {
        for (my $i = 0; $i < $start; $i++) {
            dbh()->do("select nextval(?)", {}, $seq);
        }
        $start += $number;
    }
    die "There should be some sequence" if ($start == 10);
}

############################################################################
# Browser, user agent

=item browser_get

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_get {
    my $self = shift;
    @_ = $self->{useragent}->get(@_);
    $self->_browser_html_hook();
    return @_;
}

=item browser_post

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_post {
    my $self = shift;
    @_ = $self->{useragent}->post(@_);
    $self->_browser_html_hook();
    return @_;
}

=item browser_submit_form

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_submit_form {
    my $self = shift;
    @_ = $self->{useragent}->submit_form(@_);
    $self->_browser_html_hook();
    return @_;
}

=item browser_follow_link

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_follow_link {
    my $self = shift;
    @_ = $self->{useragent}->follow_link(@_) or die "browser_follow_link failed";
    $self->_browser_html_hook();
    return @_;
}

=item browser_uri

Acts as function in WWW::Mechanize.

=cut
sub browser_uri {
    my $self = shift;
    return $self->{useragent}->uri(@_);
}

=item browser_content

Acts as function in WWW::Mechanize.

=cut
sub browser_content {
    my $self = shift;
    return $self->{useragent}->content(@_);
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

=item browser_set_validator COMMAND

Uses COMMAND to validate every HTML page browsed to.  The command should take
an HTML file as a parameter, write errors to STDERR and return an error code
only if the HTML is invalid.  /usr/bin/validate from the Debian package
wdg-html-validator is an example suitable COMMAND.

=cut
sub browser_set_validator ($$) {
    my ($self, $validator) = @_;
    $self->{htmlvalidator} = $validator;
}

# Internal use only, called each HTML page made.  Can do
# validating and logging, etc.
sub _browser_html_hook ($) {
    my ($self) = @_;

    # If validator set and HTML then validate
    if ($self->{useragent}->is_html() && defined($self->{htmlvalidator})) {
        my ($fh, $filename) = File::Temp::tempfile( DIR => $self->{tempdir}, SUFFIX => '.html');
        print $fh $self->{useragent}->content();
        close $fh;
        system($self->{htmlvalidator}, $filename) and die "HTML $filename doesn't validate, URL " . $self->{useragent}->uri();
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

=item email_setup PARAMS

Prepares for incoming email.  PARAMS is a hash reference, containing:

eveld_bin - The binary for eveld, which the email test code will run to send
outgoing messages.  Optional.

log_mailbox - Mail file to additionally put all received messages in.  Deletes
any existing file.  Optional.

=cut
sub email_setup($$) {
    my ($self, $params) = @_;
    dbh()->do("create table testharness_mail (
      id serial not null primary key,
      content text not null default '')");
    dbh()->commit();

    $self->{eveld_bin} = $params->{eveld_bin};
    $self->{log_mailbox} = $params->{log_mailbox};
    unlink $self->{log_mailbox} if $self->{log_mailbox};
}

=item email_run_eveld

Run eveld once to cause it to send all outgoing queued messages.  If eveld_bin
was not set in email_setup, does nothing.

=cut
sub email_run_eveld($) {
    my ($self) = @_;
    return if !$self->{eveld_bin};
    system($self->{eveld_bin}, "--once") and die "Failed to call eveld";
}

=item email_get_containing STRING

Returns the email containing the given STRING as an SQL expression.  i.e. Use %
for wildcard.  It is an error if no matching mails are found within a few
seconds, or there is more than one match.

=cut
sub email_get_containing($$) {
    my ($self, $check) = @_;
    $self->email_run_eveld();

    # Wait for email
    my $mails;
    my $got = 0;
    my $c = 0;
    while ($got == 0) {
        $mails = dbh()->selectall_arrayref("select id, content from testharness_mail
            where content like ?", {}, $check);
        $got = scalar @$mails;
        die "Email containing '$check' not found even after $c sec wait" if ($got == 0 && $c > 20);
        die "Too many emails found containing '$check'" if ($got > 1);
        $c++;
        sleep 1;
    }
    # Get content
    my ($id, $content) = @{$mails->[0]};
    # Save to logging mailbox
    if ($self->{log_mailbox}) {
        open LOG_MAILBOX, ">>", $self->{log_mailbox} or die "Failed to open $self->{log_mailbox} for writing.";
        print LOG_MAILBOX $content if ($self->{log_mailbox});
        close LOG_MAILBOX
    }
    # Delete from incoming queue
    dbh()->do("delete from testharness_mail where id = ?", {}, $id);
    dbh()->commit();
    # Remove quoted-printable
    # TODO: Do this properly, and return headers and body in unencoded UTF-8
    $content =~ s/=20/ /g;
    $content =~ s/=$/ /g;
    return $content;
}

=item email_check_none_left

Throws an error if there are any emails left.

=cut

sub email_check_none_left($) {
    my ($self) = @_;
    $self->email_run_eveld();
    sleep 5;
    my $emails_left = dbh()->selectrow_array("select count(*) from testharness_mail");
    die "$emails_left unexpected emails left" if $emails_left > 0;
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

=item email_check_url URL

Checks that a URL contains reasonable characters and is short enough to be
clicked on from even dodgy email clients.

=cut
sub email_check_url($) {
    my ($self, $url) = @_;
    $url =~ m#^.*/[A-Za-z0-9/]*$# or die "URL contains bad characters for an email: $url";
    die "URL is too long for an email: $url" if length($url) > 65;
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
