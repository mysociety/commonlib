#!/usr/bin/perl
#
# mySociety/WebTestHarness.pm;
# Used for testing websites.  Can do the following:
# - Rebuild a database with given schema (database_drop_reload)
# - Extend WWW::Mechanize to assert on contents, and validate HTML (browser_* functions)
# - Watch HTTP logs files for new errors (log_watcher_* functions)
# - Store email in db and check it (email_* functions)
# - Check PHP syntax for given files (php_check_syntax)
# - Miscellaneous other functions (multi_spawn)
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: WebTestHarness.pm,v 1.62 2007-08-17 09:31:23 matthew Exp $
#

# Overload of WWW::Mechanize
package mySociety::WebTestHarness::Mechanize;
use base 'WWW::Mechanize';

# ... now days, could use this hook to do validation instead of all the
# browser_* functions, but in some ways those are clearer named as they are
# from the calling code.
sub update_html {
    my ($self, $html) = @_;
    $self->WWW::Mechanize::update_html($html);
}

# Main package
package mySociety::WebTestHarness;

use File::Find;
use File::Slurp;
use File::Temp;
use File::stat;
use Fcntl;
use WWW::Mechanize;
use Data::Dumper;
use MIME::QuotedPrint;

use mySociety::Logfile;
use mySociety::DBHandle qw(dbh);
use mySociety::TempFiles;

# Enable stack backtraces upon "die"
use Carp qw(confess cluck verbose);
$SIG{__DIE__} = sub { confess @_ };
$SIG{__WARN__} = sub { cluck @_ };

# How long have to wait to be sure a mail hasn't arrived
our $mail_sleep_time = 60;
# How long to wait for a fax to arrive
our $fax_sleep_time = 5;

############################################################################
# Constructor


=item new

Create a new test harness object.

=cut
sub new ($$) {
    my ($class) = @_;
    my $self = {};

    $self->{tempdir} = File::Temp::tempdir( CLEANUP => 0 );
    $self->{useragent} = new mySociety::WebTestHarness::Mechanize(autocheck => 1);

    return bless($self, $class);
}

=item database_connect PREFIX

Connects to a database, for later commands. PREFIX is the prefix of the
mySociety configuration parameters for the database being used. e.g. PB_ for
PB_DB_NAME.  

=cut
sub database_connect($$) {
    my ($self, $db_option_prefix) = @_;

    mySociety::DBHandle::disconnect();

    $self->{dbhost} = mySociety::Config::get($db_option_prefix.'DB_HOST', undef);
    $self->{dbport} = mySociety::Config::get($db_option_prefix.'DB_PORT', undef);
    $self->{dbname}  = mySociety::Config::get($db_option_prefix.'DB_NAME');
    $self->{dbuser} = mySociety::Config::get($db_option_prefix.'DB_USER');
    $self->{dbpass} = mySociety::Config::get($db_option_prefix.'DB_PASS');

    mySociety::DBHandle::configure(Name => $self->{dbname}, 
            User => $self->{dbuser}, Password => $self->{dbpass},
            Host => $self->{dbhost}, Port => $self->{dbport});
}

=item database_drop_reload SCHEMA_FILE

Drops the database, and reloads it from the given schema.  Checks the database
has -testharness or _testharness at the end of its name to avoid clobbering
something important.

If you get "NOTICE:  CREATE TABLE will create implicit sequence" messages
and would like to supress them, edit /etc/postgresql/postgresql.conf, setting
    client_min_messages = warning 

=cut
sub database_drop_reload ($$)
{
    my ($self, $schema_file) = @_;

    # Drop and recreate database from schema
    die "Database will be dropped, so for safety must have name ending '_testharness' or '-testharness'" if ($self->{dbname} !~ m/[_-]testharness$/);

    # ... make connection with no database name and drop and remake database
    my $connstr = 'dbi:Pg:';
    $connstr .= "host=".$self->{dbhost}.";" if ($self->{dbhost});
    $connstr .= "port=".$self->{dbport}.";" if ($self->{dbport});
    $connstr .= "dbname=template1;";
    my $db_remake_db = DBI->connect($connstr, $self->{dbuser}, $self->{dbpass}, {
                            RaiseError => 1, AutoCommit => 1, PrintError => 0, PrintWarn => 1, });
    my $c = $db_remake_db->selectrow_array("select count(*) from pg_database where datname = '$self->{dbname}'");
    if ($c > 0) {
        $db_remake_db->do("drop database \"$self->{dbname}\"");
    }
    $db_remake_db->do("create database \"$self->{dbname}\"");
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
    dbh()->do("set client_min_messages to warning"); # So implicit index creation NOTICEs aren't displayed when loading SQL
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
    $_ = $self->{useragent}->submit_form(@_) or die "browser_submit_form failed";
    $self->_browser_html_hook();
    return $_;
}

=item browser_form_name

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_form_name {
    my $self = shift;
    $_ = $self->{useragent}->form_name(@_) or die "browser_form_name failed";
    $self->_browser_html_hook();
    return $_;
}

=item browser_field

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_field {
    my $self = shift;
    $_ = $self->{useragent}->field(@_);
    $self->_browser_html_hook();
    return $_;
}

=item browser_follow_link

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_follow_link {
    my $self = shift;
    $_ = $self->{useragent}->follow_link(@_) or die "browser_follow_link failed";
    $self->_browser_html_hook();
    return $_;
}

=item browser_back

Acts as function in WWW::Mechanize, but intercepts HTML pages
for validating and logging.

=cut
sub browser_back {
    my $self = shift;
    $_ = $self->{useragent}->back(@_) or die "browser_back failed";
    $self->_browser_html_hook();
    return $_;
}

=item browser_uri

Acts as function in WWW::Mechanize.

=cut
sub browser_uri {
    my $self = shift;
    return $self->{useragent}->uri(@_);
}

=item browser_base

Acts as function in WWW::Mechanize.

=cut
sub browser_base {
    my $self = shift;
    return $self->{useragent}->base(@_);
}

=item browser_content

Acts as function in WWW::Mechanize.

=cut
sub browser_content {
    my $self = shift;
    return $self->{useragent}->content(@_);
}

=item browser_reload

Acts as function in WWW::Mechanize.

=cut
sub browser_reload {
    my $self = shift;
    return $self->{useragent}->reload(@_);
}

=item browser_credentials

Acts as function in WWW::Mechanize.

=cut
sub browser_credentials {
    my $self = shift;
    return $self->{useragent}->credentials(@_);
}

=item browser_check_contents STRING/REGEXP

Checks the current page which is being browsed contains the given string
or regular expression.

=cut
sub browser_check_contents ($$) {
    my ($self, $check) = @_;
    if ($self->{useragent}->content !~ m/$check/) {
        $filename = $self->_browser_debug_content();
        die "URL " . $self->{useragent}->uri() . " does not contain '" . $check . "', contents is in $filename";
    }
}

=item browser_check_no_contents STRING

Checks the current page which is being browsed does not contain the given
string.

=cut
sub browser_check_no_contents ($$) {
    my ($self, $check) = @_;
    if ($self->{useragent}->content =~ m/$check/) {
        $filename = $self->_browser_debug_content();
        die "URL " . $self->{useragent}->uri() . " unexpectedly contains '" . $check . "', full contents is in $filename";
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

    # If log watcher, check the log file
    if ($self->{http_logobj}) {
        $self->log_watcher_check();
    }

    # If validator set and HTML then validate
    if ($self->{useragent}->is_html() && defined($self->{htmlvalidator})) {
        $filename = $self->_browser_debug_content();
        system($self->{htmlvalidator}, $filename) and die "HTML $filename doesn't validate, URL " . $self->{useragent}->uri();
        unlink $filename;
    }
}

# Print content to a file for debugging
sub _browser_debug_content ($) {
    my ($self) = @_;
    my ($fh, $filename) = File::Temp::tempfile( DIR => $self->{tempdir}, SUFFIX => '.html');
    print $fh $self->{useragent}->content();
    close $fh;
    return $filename;
}

############################################################################
# Log watcher

=item log_watcher_setup LOG_FILENAME

Configures test harness to watch an HTTP error log file.

=cut
sub log_watcher_setup ($$) {
    my ($self, $file) = @_;

    # Make sure log file is non-zero (LogFile.pm requires this for mmap)
    my $st = stat($file) or die ("$file: $!");
    if ($st->size() == 0) {
        open NON_ZERO, ">>", $file or die "Failed to open $file for writing, to make it not zero length.";
        print NON_ZERO "WebTestHarness added line to make log non-zero length\n";
        close NON_ZERO
    
    }

    # Create logging object
    $self->{http_logobj} = new mySociety::Logfile($file);
    $self->{http_logoffset} = $self->{http_logobj}->lastline();
}

=item log_watcher_self_test ERROR_URL ERROR_LOG_REGEXP

Verifies that errors can be detected by the web log error file watching
code. Call this after calling log_watcher_setup. ERROR_URL is a URL
on the site which deliberately causes an error to be written to the
error log. ERROR_LOG_REGEXP is a regular expression which that error
log message matches.

=cut 
sub log_watcher_self_test {
    my ($self, $self_test_url, $regexp) = @_;
    $self->log_watcher_check();
    $self->{useragent}->get($self_test_url); # do the get without calling _browser_html_hook
    my $errors = $self->_log_watcher_get_errors();
    die "Unable to detect errors from PHP" if ($errors !~ m/$regexp/);
}

# Returns error text if there are new errors since last call, or empty string
# (which is false) otherwise. 
sub _log_watcher_get_errors ($) {
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

If log_watcher_setup was called, then this is called automatically for each
page browsed. So you only need to call this at the end, or if something other
than browsing the site via this class might cause web error logs to be written.

=cut
sub log_watcher_check($) {     
    my ($self) = @_;
    my $errors = $self->_log_watcher_get_errors();
    die $errors if ($errors);
}

############################################################################
# Email

=item email_setup PARAMS

Prepares for incoming email.  PARAMS is a hash reference, containing:

eveld_bin - The binary for eveld, which the email test code will run to send
outgoing messages.  Optional (not needed if you run a daemon, but set
EVEL_DAEMON_QUEUE_RUN_INTERVAL to a low value).

eveld_multispawn - Number of times to spawn eveld_bin at once, to test for
concurrency problems. Optional, default 1.

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
    $self->{eveld_multispawn} = $params->{eveld_multispawn};
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
    my $multispawn = $self->{eveld_multispawn};
    $multispawn = 1 if !$multispawn;
    $self->multi_spawn($multispawn, $self->{eveld_bin} . " --once", 0); # TODO: pass verbose in?
}

=item email_get_containing STRING

Returns the email containing the given STRING as an SQL expression.  i.e. Use %
for wildcard.  STRING can also be an array of such strings, any of which need 
to match. It is an error if no matching mails are found within a few seconds,
or there is more than one match.  The email is returned with any quoted
printable characters decoded.

=cut
sub email_get_containing($$) {
    my ($self, $check) = @_;
    
    die "STRING must be scalar or array" if (ref($check) ne 'ARRAY' && ref($check) ne '');
    $check = [ $check ] if (ref($check) eq '');

    # need search string in quoted-printable, as email in the database is
    # encoded like that
    my @params;
    foreach my $c (@$check) {
        my $quoted_c = encode_qp($c, "");
        push @params, $quoted_c;
    }
    $qfragment = join(' or ' , map { 'content like ?' } @params);
    $qdesc = join(' or ' , map { "'$_'" } @params);

    # Provoke any sending of mails
    $self->email_run_eveld();

    # Wait for email
    my $mails;
    my $got = 0;
    my $c = 0;
    while ($got == 0) {
        $mails = dbh()->selectall_arrayref("select id, content from testharness_mail
            where $qfragment", {}, @params);
        $got = scalar @$mails;
        die "Email containing $qdesc not found even after $c sec wait" if ($got == 0 && $c > $mail_sleep_time);
        die "Too many emails found containing $qdesc" if ($got > 1);
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
    my $unquoted_content;
    $unquoted_content = decode_qp($content);
    return $unquoted_content;
}

=item email_check_none_left

Dies if there are any emails left.

=cut

sub email_check_none_left($;$) {
    my ($self, $long) = @_;
    $self->email_run_eveld();
    sleep ($long ? $mail_sleep_time : 2);
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
    $url =~ s/testharness\.//; 
    die "URL is too long for an email: $url" if length($url) > 65;
}

############################################################################
# Fax

=item fax_setup

Prepares a database table for incoming faxes.

=cut
sub fax_setup($) {
    my ($self) = @_;
    dbh()->do("create table testharness_fax (
      id serial not null primary key,
      pages integer not null,
      sent_to text not null)");
    dbh()->commit();
}

=item fax_get_sent_to FAX_NUMBER PAGES

Returns the fax whose sent_to field matches the given FAX_NUMBER and whose
number of pages is PAGES. It is an error if no matching faxes are found,
or there is more than one match.

=cut
sub fax_get_sent_to($$$) {
    my ($self, $fax_number, $pages) = @_;
    my $faxes;
    my $c = 0;
    my $got = 0;

    while ($got == 0) {
        $faxes = dbh()->selectall_arrayref("select id from testharness_fax
            where sent_to = ? and pages = ?", {}, $fax_number, $pages);
        $got = scalar @$faxes;
        die "$pages page fax sent to $fax_number not found even after $c sec wait" if ($got == 0 && $c > $fax_sleep_time);
        die "Too many $pages page faxes found sent to $fax_number" if ($got > 1);
        $c++;
        sleep 1;
    }
    my ($id) = @{$faxes->[0]};

    # Delete from incoming queue
    dbh()->do("delete from testharness_fax where id = ?", {}, $id);
    dbh()->commit();
    return undef;
}

=item fax_check_none_left

Dies if there are any faxes left.

=cut

sub fax_check_none_left($) {
    my ($self) = @_;
    my $faxes_left = dbh()->selectrow_array("select count(*) from testharness_fax");
    die "$faxes_left unexpected faxes left" if $faxes_left > 0;
}


=item fax_incoming FAX_NUMBER PAGES PAGEFILES LOG_FAXDIR

Call when a new fax arrives, and its details will be stored for access via
fax_get_containing. If log_faxdir is set, the fax pages themselves will be
stored as jpg files in the LOG_FAXDIR directory.

=cut
sub fax_incoming($$$$$) {
    my ($self, $fax_number, $pages, $pagefiles, $log_faxdir) = @_;
    if (defined($log_faxdir)){
        mkdir($log_faxdir, 0755) if (!-d $log_faxdir) ;
    }
    dbh()->do("insert into testharness_fax (sent_to, pages) values (?, ?)", {}, $fax_number, $pages);
    dbh()->commit();

    # Save image files as jpgs to the logging directory
    if (defined($log_faxdir)){

        my $tempfile;
        my $logfile;
        my $pagenum = 1;
        my ($p, $pid);

        foreach $tempfile (@$pagefiles){
            # Pipe the PBM temp file through the ppmtojpeg utility
            $logfile = $log_faxdir . "/" . $fax_number . "_p" . $pagenum . '.jpg';
            ++$pagenum;
            if (my $f = new IO::File($logfile, O_WRONLY | O_CREAT | O_TRUNC, 0644)){
                ($p, $pid) = mySociety::TempFiles::pipe_via("ppmtojpeg $tempfile", $f);
                $f->close() or die "close: $logfile $!";;
                $p->close() or die "close: $!";
                waitpid($pid, 0);
                if ($?) {
                    # Something went wrong.
                    if ($? & 127) {
                        die "ppmtojpeg died with signal " . ($? & 127);
                    } else {
                        die "ppmtojpeg exited with status " . ($? >> 8);
                    }
                }
            }else{
                die "Couldn't create log file of fax page $logfile";
            }
        }

    }
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
# Extra functions

=item multi_spawn NUMBER_OF_TIMES COMMAND VERBOSE

Launch the COMMAND multiple times, and wait for them all to finish. Die if any
of them return an error code. This is useful for testing the COMMAND works when
run concurrently (say from cron on multiple servers). Print the command being
run, and how many copies, if VERBOSE >= 2.

=cut
sub multi_spawn($$$) {
    my ($self, $nprocs, $command, $verbose) = @_;
    print "$nprocs x $command\n" if $verbose >= 2;

    my @pids; 
    for (my $i = 0; $i < $nprocs; ++$i) { 
        my $p = fork(); 
        if ($p) { 
            push(@pids, $p); 
        } else { 
            { exec("/bin/sh", "-c", $command); } 
            die "Couldn't exec '$command'";
        } 
    } 
        
    for (my $i = 0; $i < @pids; ++$i) { 
        waitpid($pids[$i], 0);
        die "exit code $? from '$command'" if ($? != 0);
    }
}

1;
