#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Util.pm,v 1.2 2004-10-19 16:46:31 chris Exp $
#

package mySociety::Util;

use strict;
use Error qw(:try);
use IO::File;
use Fcntl;

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
that file. If specified, SUFFIX a suffix which will be appended to the filename
(include any leading dot if you want to create, e.g., files called "foo.html"
or whatever).

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
    try {
        my $pid;
        defined($pid = open(SENDMAIL, '|-')) or die "fork: $!\n";
        if (0 == $pid) {
            # Child.
            # XXX should close all other fds
            exec('/usr/libexec/sendmail',
                    '-i',
                    '-f', $sender,
                    @recips);
            die;
        }

        print SENDMAIL $text or die "write: $!\n";

        close SENDMAIL or die "close: $!\n";

        if ($? & 127) {
            die sprintf("sendmail: killed by signal %d\n", $? & 127);
        } elsif ($?) {
            die sprintf("sendmail: failure exit status %d\n", $? >> 8);
        }
    } catch Error::Simple with {
        my $e = shift;
        close(SENDMAIL);
        return $e->text();
    };
    return undef;
}

1;
