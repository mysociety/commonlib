#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Util.pm,v 1.4 2004-10-20 16:56:13 chris Exp $
#

package mySociety::Util;

use strict;
use Error qw(:try);
use IO::File;
use Fcntl;
use POSIX;

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
mail. Returns undef on success or an error string on failure.

=cut
sub send_email ($$@) {
    my ($text, $sender, @recips) = @_;
    my $pid;
    eval {
#        local $SIG{PIPE} = 'IGNORE';
        my $pid;
        defined($pid = open(SENDMAIL, '|-')) or die "fork: $!\n";
        if (0 == $pid) {
            # Close all filehandles other than standard ones. This will prevent
            # perl from messing up database connections etc. on exit.
            for (my $fd = 3; $fd < 1024; ++$fd) {
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
            die sprintf("sendmail: killed by signal %d\n", $? & 127);
        } elsif ($?) {
            die sprintf("sendmail: failure exit status %d\n", $? >> 8);
        }
    };
    close(SENDMAIL);
    $@ =~ s/\n//;
    return $@;
}

=item is_valid_postcode STRING

Is STRING (once it has been converted to upper-case and spaces removed) a valid
UK postcode (as defined by BS7666, apparently).

=cut
sub is_valid_postcode ($) {
    my $pc = uc($_[0]);
    $pc =~ s#\s##g;
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
