#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Util.pm,v 1.6 2004-11-15 11:09:42 francis Exp $
#

package mySociety::Util;

use strict;
use Error qw(:try);
use IO::File;
use Fcntl;
use POSIX;
use Sys::Syslog;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&print_log);
}
our @EXPORT_OK;

=head1 NAME

mySociety::Util

=head1 DESCRIPTION

Various useful functions for applications, without any organising principle.

=head1 FUNCTIONS

=over 4

=item random_bytes NUMBER

Return the given NUMBER of random bytes from /dev/random.

=cut
sub random_bytes ($) {
    my ($count) = @_;

    no utf8;

    our $f;
    if (!$f) {
        $f = new IO::File("/dev/random", O_RDONLY) or die "/dev/random: $!";
    }

    my $l = '';

    while (length($l) < $count) {
        $f->sysread($l, $count - length($l), length($l)) or die "/dev/random: $!";
    }

    return $l;
}

=item named_tempfile [SUFFIX]

Return in list context an IO::Handle open on a temporary file, and the name of
that file. If specified, SUFFIX gives a suffix which will be appended to the
filename (include any leading dot if you want to create, e.g., files called
"foo.html" or whatever). Dies on error.

=cut
sub named_tempfile (;$) {
    my ($suffix) = @_;
    $suffix ||= '';
    my ($where) = grep { -d $_ and -w $_ } ($ENV{TEMP}, $ENV{TMPDIR}, $ENV{TEMPDIR}, "/tmp");
    die "no temporary directory available (last tried was \"$where\", error was $!)" unless (defined($where));
    
    my $prefix = $0;
    $prefix =~ s#^.*/##;
    my $name;
    for (my $i = 0; $i < 10; ++$i) {
        $name = sprintf('%s/%s-temp-%08x-%08x%s', $where, $prefix, int(rand(0xffffffff)), int(rand(0xffffffff)), $suffix);
        if (my $h = new IO::File($name, O_WRONLY | O_CREAT | O_EXCL, 0600)) {
            return ($h, $name);
        }
    }

    die "unable to create temporary file; last attempted name was \"$name\" and open failed with error $!";
}

=item send_email TEXT SENDER RECIPIENT ...

Send an email. TEXT is the full, already-formatted, with-headers, on-the-wire
form of the email (except that line-endings should be "\n" not "\r\n"). SENDER
is the B<envelope> sender of the mail (B<not> the From: address, which you
should specify yourself). RECIPIENTs are the B<envelope> recipients of the
mail. Returns one of the constants EMAIL_SUCCESS, EMAIL_SOFT_FAILURE, or
EMAIL_HARD_FAILURE depending on whether the email was successfully sent (or
queued), a temporary ("soft") error occurred, or a permanent ("hard") error
occurred.

=cut
use constant EMAIL_SUCCESS => 0;
use constant EMAIL_SOFT_ERROR => 1;
use constant EMAIL_HARD_ERROR => 2;
sub send_email ($$@) {
    my ($text, $sender, @recips) = @_;
    my $pid;
    my $ret;
#    local $SIG{PIPE} = 'IGNORE';
    defined($pid = open(SENDMAIL, '|-')) or die "fork: $!\n";
    if (0 == $pid) {
        # Close all filehandles other than standard ones. This will prevent
        # perl from messing up database connections etc. on exit.
        for (my $fd = 3; $fd < POSIX::sysconf(POSIX::_SC_OPEN_MAX); ++$fd) {
            POSIX::close($fd);
        }
        # Child.
        # XXX should close all other fds
        exec('/usr/sbin/sendmail',
                '-i',
                '-f', $sender,
                @recips);
        exit(255);
    }

    print SENDMAIL $text or die "write: $!\n";
    close SENDMAIL;

    if ($? & 127) {
        # Killed by signal; assume that message was not queued.
        $ret = EMAIL_HARD_ERROR;
    } elsif ($?) {
        # We need to distinguish between success (anything which means that
        # the message will later be delivered or bounced), soft failures
        # (for which redelivery should be attempted later) and hard
        # failures (which mean that delivery will not succeed even if
        # retried).
        #
        # From sendmail(8):
        #
        # Sendmail returns an exit status describing what it did.  The
        # codes are defined in <sysexits.h>:
        #
        #   EX_OK           Successful completion on all addresses.
        #   EX_NOUSER       User name not recognized.
        #   EX_UNAVAILABLE  Catchall meaning necessary resources were not
        #                   available.
        #   EX_SYNTAX       Syntax error in address.
        #   EX_SOFTWARE     Internal software error, including bad
        #                   arguments.
        #   EX_OSERR        Temporary operating system error, such as
        #                   "cannot fork."
        #   EX_NOHOST       Host name not recognized.
        #   EX_TEMPFAIL     Message could not be sent immediately, but was
        #                   queued.
        my $ex = ($? >> 8);
        
        my %return_codes = (
                0       => EMAIL_SUCCESS,       # EX_OK
                75      => EMAIL_SUCCESS,       # EX_TEMPFAIL

                69      => EMAIL_SOFT_ERROR,    # EX_UNAVAILABLE
                71      => EMAIL_SOFT_ERROR     # EX_OSERR

                # all others: assume hard failure.
            );
        
        if (exists($return_codes{$ex})) {
            $ret = $return_codes{$ex};
        } else {
            $ret = EMAIL_HARD_ERROR;
        }
    }
    close(SENDMAIL);
    return $ret;
}

=item daemon 

Become a daemon.

=cut
sub daemon () {
    my $p;
    die "fork: $!" if (!defined($p = fork()));
    return unless ($p == 0);
    chdir("/");
    open(STDIN, "/dev/null") or die "/dev/null: $!";
    open(STDOUT, ">/dev/null") or die "/dev/null: $!";
    # Close all other fds.
    for (my $fd = 3; $fd < POSIX::sysconf(POSIX::_SC_OPEN_MAX); ++$fd) {
        POSIX::close($fd);
    }
    setsid() or die "setsid: $!";
    die "fork: $!" if (!defined($p = fork()));
    exit(0) if ($p != 0);
    open(STDERR, ">&STDOUT") or die "dup: $!";
}

=item open_log TAG

Start system logging, under TAG. If you don't call this explicitly, the first
call to print_log will, constructing an appropriate tag from $0.

=cut
my $logopen;
sub open_log ($) {
    Sys::Syslog::setlogsock('unix');    # Sys::Syslog is nasty
    openlog($_[0], 'pid,ndelay', 'daemon');    
    $logopen = $_[0];
}

=item print_log PRIORITY TEXT

Log TEXT to the system log (under PRIORITY) and to standard error. Designed for
use from daemons etc; web scripts should just log to standard error.

=cut
sub logmsg ($$) {
    if (!defined($logopen)) {
        my $tag = $0;
        $tag =~ s#^.*/##;
        logopen($tag);
    }
    my ($pri, @a) = @_;
    STDERR->print("consolidatemgrd: ", @a, "\n");
    my $x = join('', @a);
    syslog($pri, '%s', $x);    
}

=item is_valid_postcode STRING

Is STRING (once it has been converted to upper-case and spaces removed) a valid
UK postcode (as defined by BS7666, apparently).

=cut
sub is_valid_postcode ($) {
    my $pc = uc($_[0]);
    $pc =~ s#\s##g;

    # Our test postcode
    return 1 if $pc = 'ZZ99ZZ';
    
    # See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    my $in  = 'ABDEFGHJLNPQRSTUWXYZ';
    my $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    my $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    my $thd = 'ABCDEFGHJKSTUW';
    my $fth = 'ABEHMNPRVWXY';

    return 1 if ($pc =~ m#^[$fst]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d[$thd]\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d[$fth]\d[$in][$in]$#);
    return 0;
}

1;
