#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities, split into modules
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#


package mySociety::Util::Error;

@mySociety::Util::Error::ISA = qw(Error::Simple);

package mySociety::Util;

use strict;

=begin
use Errno;
use Error qw(:try);
use Fcntl;
use File::stat;
use Getopt::Std;
use IO::File;
use IO::Handle;
use IO::Pipe;
use Net::SMTP;
use POSIX ();
use Sys::Syslog;
use Statistics::Distributions qw(fdistr);
use Data::Dumper;
=cut

use mySociety::EmailUtil;
use mySociety::HTMLUtil;
use mySociety::PostcodeUtil;
use mySociety::Random;
use mySociety::Sundries;
use mySociety::SystemMisc;
use mySociety::TempFiles;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&open_log &print_log &printf_log &random_bytes &ordinal &is_valid_email &is_valid_postcode &create_file_to_replace &shell &describe_waitval &send_email);
}
our @EXPORT_OK;

=head1 NAME

mySociety::Util

=head1 DESCRIPTION

Do not use this package. Instead use the following: 

=over 4

=item mySociety::EmailUtil

=item mySociety::HTMLUtil

=item mySociety::PostcodeUtil

=item mySociety::Random

=item mySociety::Sundries

=item mySociety::SystemMisc

=item mySociety::TempFiles

=back

=cut
sub random_bytes ($;$) {
    goto &mySociety::Random::random_bytes;
}

sub named_tempfile (;$) {
    goto &mySociety::TempFiles::named_tempfile;
}

sub tempdir (;$) {
    goto &mySociety::TempFiles::tempdir;
}

sub tempdir_cleanup ($) {
    goto &mySociety::TempFiles::tempdir_cleanup;
}

sub pipe_via (@) {
    goto &mySociety::TempFiles::pipe_via;
}

sub send_email_sendmail ($$@) {
    goto &mySociety::EmailUtil::send_email_sendmail;
}

sub send_email_smtp ($$$@) {
    goto &mySociety::EmailUtil::send_email_smtp;
}

sub send_email ($$@) {
    goto &mySociety::EmailUtil::send_email;
}

sub daemon () {
    goto &mySociety::SystemMisc::daemon;
}

sub open_log ($) {
    goto &mySociety::SystemMisc::open_log;
}

sub log_to_stderr (;$) {
    goto &mySociety::SystemMisc::log_to_stderr;
}

sub print_log ($$) {
    goto &mySociety::SystemMisc::print_log;
}

sub printf_log ($$@) {
    goto &mySociety::SystemMisc::printf_log;
}

sub manage_child_processes ($;$) {
    goto &mySociety::SystemMisc::manage_child_processes;
}

sub is_valid_postcode ($) {
    goto &mySociety::PostcodeUtil::is_valid_postcode;
}

sub is_valid_partial_postcode ($) {
    goto &mySociety::PostcodeUtil::is_valid_partial_postcode;
}

sub ordinal ($) {
    goto &mySociety::Sundries::ordinal;
}

sub is_valid_email ($) {
    goto &mySociety::EmailUtil::is_valid_email;
}

sub create_accessor_methods () {
    goto &mySociety::Sundries::create_accessor_methods;
}

sub create_file_to_replace ($) {
    goto &mySociety::TempFiles::create_file_to_replace;
}

sub kill_named_processes ($$) {
    goto &mySociety::SystemMisc::kill_named_processes;
}

sub shell {
    goto &mySociety::SystemMisc::shell;
}

sub describe_waitval ($;$) {
    goto &mySociety::SystemMisc::describe_waitval;
}

sub binomial_confidence_interval ($$) {
    goto &mySociety::Sundries::binomial_confidence_interval;
}

sub ms_make_clickable {
    goto &mySociety::HTMLUtil::ms_make_clickable;
}

sub nl2br {
    goto &mySociety::HTMLUtil::nl2br;
}


1;
