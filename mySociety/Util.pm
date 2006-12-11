#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Util.pm,v 1.60 2006-12-11 16:38:14 francis Exp $
#

# TODO: Separate out all the daemon and process launching functions
# into their own file.

package mySociety::Util::Error;

@mySociety::Util::Error::ISA = qw(Error::Simple);

package mySociety::Util;

use strict;

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

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&open_log &print_log &printf_log &random_bytes &ordinal &is_valid_email &is_valid_postcode &create_file_to_replace &shell &describe_waitval &send_email);
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
        $f = new IO::File("/dev/random", O_RDONLY) or die "open /dev/random: $!";
    }

    my $l = '';

    while (length($l) < $count) {
        my $n = $f->sysread($l, $count - length($l), length($l));
        if (!defined($n)) {
            die "read /dev/random: $!";
        } elsif (!$n) {
            die "read /dev/random: EOF (shouldn't happen)";
        }
    }

    die "wanted $count bytes, got " . length($l) . " bytes" unless (length($l) == $count);

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
    my ($where) = grep { defined($_) and -d $_ and -w $_ } ($ENV{TEMP}, $ENV{TMPDIR}, $ENV{TEMPDIR}, "/tmp");
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

=item tempdir [PREFIX]

Return the name of a newly-created temporary directory. The directory will be
created with mode 0700. If specified, PREFIX specifies the first part of the
name of the new directory; otherwise, the last part of $0 is used. Dies on
error.

=cut
sub tempdir (;$) {
    my ($prefix) = @_;
    if (!$prefix) {
        $prefix = $0;
        $prefix =~ s#^.*/##;
    }
    my ($where) = grep { defined($_) and -d $_ and -w $_ } ($ENV{TEMP}, $ENV{TMPDIR}, $ENV{TEMPDIR}, "/tmp");
    die "no temporary directory available (last tried was \"$where\", error was $!)" unless (defined($where));
    my $name;
    while (1) {
        $name = sprintf('%s/%s-temp-%08x-%08x', $where, $prefix, int(rand(0xffffffff)), int(rand(0xffffffff)));
        if (mkdir($name, 0700)) {
            return $name;
        } elsif (!$!{EEXIST}) {
            die "$name: mkdir: $!";
        }
    }
}

=item tempdir_cleanup DIRECTORY

Delete DIRECTORY and its contents.

=cut
sub tempdir_cleanup ($) {
    my ($tempdir) = @_;
    die "$tempdir: not a directory" if (!-d $tempdir);
    system('/bin/rm', '-rf', $tempdir); # XXX
}

=item pipe_via PROGRAM [ARG ...] [HANDLE]

Sets up a pipe via the given PROGRAM (passing it the given ARGs), and (if
given) connecting its standard output to HANDLE. If called in list context,
returns the handle and the PID of the child process. Dies on error.

=cut
sub pipe_via (@) {
    my ($prog, @args) = @_;
    my $outh;
    if (scalar(@args) and UNIVERSAL::isa($args[$#args], 'IO::Handle')) {
        $outh = pop(@args)->fileno();
    }

    my ($rd, $wr) = POSIX::pipe() or die "pipe: $!";

    my $child = fork();
    die "fork: $!" if (!defined($child));

    if ($child == 0) {
        POSIX::close($wr);
        POSIX::close(0);
        POSIX::dup($rd);
        POSIX::close($rd);
        if (defined($outh)) {
            POSIX::close(1);
            POSIX::dup($outh);
            POSIX::close($outh);
        }
        { exec($prog, @args); }
        print STDERR "$prog: execve: $!\n";
        POSIX::_exit(255);
    }

    POSIX::close($rd) or die "close: $!";

    my $p = new IO::Handle() or die "create handle: $!";
    $p->fdopen($wr, "w") or die "fdopen: $!";
    if (wantarray()) {
        return ($p, $child);
    } else {
        return $p;
    }
}

use constant EMAIL_SUCCESS => 0;
use constant EMAIL_SOFT_ERROR => 1;
use constant EMAIL_HARD_ERROR => 2;

# send_email_sendmail TEXT SENDER RECIPIENT ...
# Implementation of send_email which calls out to /usr/sbin/sendmail.
sub send_email_sendmail ($$@) {
    my ($text, $sender, @recips) = @_;
    my $pid;
    my $ret;
#    local $SIG{PIPE} = 'IGNORE';
    defined($pid = open(SENDMAIL, '|-')) or die "fork: $!\n";
    if (0 == $pid) {
        # Close all filehandles other than standard ones. This will prevent
        # perl from messing up database connections etc. on exit.
        use POSIX;
        my $openmax = POSIX::_SC_OPEN_MAX();
        for (my $fd = 3; $fd < POSIX::sysconf($openmax); ++$fd) {
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
    } else {
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
        #
        # BUT Exim only returns EXIT_SUCCESS (0) or EXIT_FAILURE (1), and does
        # not distinguish permanent from temporary failure. Which means that
        # this isn't a lot of good.
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

# send_email_smtp SMARTHOST TEXT SENDER RECIPIENT ...
# Implementation of send_email which calls out to an SMTP server.
sub send_email_smtp ($$$@) {
    my ($smarthost, $text, $sender, @recips) = @_;
    my $smtp = new Net::SMTP($smarthost, Timeout => 15);
    return EMAIL_SOFT_ERROR if (!$smtp);

    # Actually this could be a hard error, but since that could only really be
    # the result of a misconfiguration, treat it as a soft error and give the
    # admins a chance to fix the problem.
    return EMAIL_SOFT_ERROR
        unless ($smtp->mail($sender));

    foreach my $addr (@recips) {
        if (!$smtp->to($addr)) {
            # 5xx means "known to be undeliverable".
            my $c = $smtp->code();
            return (defined($c) && $c =~ /^5..$/)
                    ? EMAIL_HARD_ERROR
                    : EMAIL_SOFT_ERROR;
        }
    }

    my @ll = map { "$_\r\n" } split(/\n/, $text);
    return EMAIL_SOFT_ERROR
        unless ($smtp->data(\@ll));

    $smtp->quit();
    undef $smtp;
    return EMAIL_SUCCESS;
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
sub send_email ($$@) {
    my ($text, $sender, @recips) = @_;
    my $smarthost = mySociety::Config::get('SMTP_SMARTHOST', undef);
    if ($smarthost) {
        return send_email_smtp($smarthost, $text, $sender, @recips);
    } else {
        warn "No OPTION_SMTP_SMARTHOST defined; calling sendmail binary instead";
        return send_email_sendmail($text, $sender, @recips);
    }
}

=item daemon 

Become a daemon.

=cut
sub daemon () {
    my $p;
    die "fork: $!" if (!defined($p = fork()));
    exit(0) unless ($p == 0);
    # Should chdir("/"), but that's a bad idea because of the way we locate
    # config files etc.
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
my ($logopen, $savedlogtag, $triedconnect);
sub open_log ($) {
    # Wrap the openlog call in eval because it will fail if it can't connect
    # to /dev/log (god alone knows why -- it's a datagram socket, so they could
    # just use sendto). It's possible (though unlikely) that the connection
    # could fail, but this doesn't matter because we'd just call openlog again
    # on the next invocation of print_log. However, openlog's default behaviour
    # is to die if connect fails.
    $savedlogtag ||= $_[0];
    my $w;
    eval {
        $SIG{__WARN__} = sub { $w = $_[0] };
        Sys::Syslog::setlogsock('unix');    # Sys::Syslog is nasty
        openlog($_[0], 'pid,ndelay', 'daemon');
        $logopen = $_[0];
    };
    $w =~ s# at .+line \d+$##;
    if (!$logopen && !$triedconnect) {
        print STDERR "$_[0]: open_log: $w";
        print STDERR "$_[0]: that means that errors will not be logged to the system log, at least until we're able to connect to /dev/log\n";
        $triedconnect = 1;
    }
}

=item log_to_stderr [FLAG]

Get or set the flag for sending log messages to standard error as well as the
system log. By default this is on.

=cut
my $logtostderr = 1;
sub log_to_stderr (;$) {
    my $r = $logtostderr;
    $logtostderr = $_[0] if (defined($_[0]));
    return $r;
}

=item print_log PRIORITY TEXT

=item printf_log PRIORITY FORMAT [ARGUMENT ...]

Log TEXT to the system log (under PRIORITY) and to standard error. Designed for
use from daemons etc; web scripts should just log to standard error. printf_log
is the printf(3) analogue.

=cut
sub print_log ($$) {
    my $tag = $logopen;
    if (!defined($tag)) {
        $tag = $savedlogtag;
        if (!$tag) {
            $tag = $0;
            $tag =~ s#^.*/##;
        }
        open_log($tag);
    }
    my ($pri, @a) = @_;
    my $str = join('', @a);
    chomp($str);
    # Log to standard error if either we have been told to explicitly, or we
    # have not been able to open the log.
    STDERR->print("$tag: ", $str, "\n") if ($logtostderr || ($triedconnect && !$logopen));
    syslog($pri, '%s', $str) if ($logopen);
}

sub printf_log ($$@) {
    my $pri = shift;
    my $fmt = shift;
    my $str = sprintf($fmt, @_);
    print_log($pri, $str);
}

=item manage_child_processes SPEC [SIGNALS]

Manage a set of child processes according to the SPEC. SPEC is a reference to
a hash of NAME to [NUM, FUNCTION].  For each such entry manage_child_processes
will try to fork NUM processes, each of which will call FUNCTION and then exit.
NAME is a descriptive name for logging. manage_child_processes will catch
SIGINT, SIGTERM and SIGHUP (or, optionally, the given list of SIGNALS); on
catching a signal it will kill all currently-running child processes with
SIGTERM and return the number of the caught signal. No change is made to the
signal-handlers in the child processes, so they should arrange to catch
SIGTERM. If a child process exits otherwise, it will be restarted.

=cut
sub manage_child_processes ($;$) {
    my ($spec, $signals) = @_;
    die "SPEC must be reference-to-hash"
        unless (defined($spec) && ref($spec) eq 'HASH');
    die "SIGNALS must be undef or reference-to-list"
        unless (!defined($signals) || ref($signals) eq 'ARRAY');
    $signals ||= [POSIX::SIGINT, POSIX::SIGTERM, POSIX::SIGHUP];

    my $foad = 0;
    
    # For safety, do everything here with POSIX signal handling.
    my %oldSIG;
    $oldSIG{&POSIX::SIGCHLD} = new POSIX::SigAction();
    POSIX::sigaction(POSIX::SIGCHLD, new POSIX::SigAction(sub { }, undef, POSIX::SA_RESTART), $oldSIG{&POSIX::SIGCHLD});

    # Need to be able to block and unblock SIGCHLD too.
    my $schld = new POSIX::SigSet(POSIX::SIGCHLD) or die "sigset: $!";

    # This is horrid. Perl can refer to signals by name or number. So we need
    # to be able to deal with either.
    foreach my $s (@$signals) {
        if ($s =~ /[^\d]/) {
            my $x = eval "&POSIX::SIG$s" || eval "&POSIX::$s";
            if (defined($x) && $x !~ /[^\d]/) {
                $s = $x;
            } else {
                die "unknown signal '$s'";
            }
        }
        # Need to be able to restore old signal handler in child.
        my $act = new POSIX::SigAction(sub { $foad = $s }, undef, POSIX::SA_RESTART);
        $act->safe(1);
        $oldSIG{$s} = new POSIX::SigAction();
        POSIX::sigaction($s, $act, $oldSIG{$s});
    }

    # hash of PID to [type, start time].
    my %processes = ( );
    
    my %count = map { $_ => 0 } keys %$spec;
    while (!$foad) {
        my %tostart = ( );
        POSIX::sigprocmask(POSIX::SIG_BLOCK, $schld);

        foreach (keys %$spec) {
            my $n = $spec->{$_}->[0] - $count{$_};
            if ($n < 0) {
                $n *= -1;
                print_log('warn', "oops: we seem to have $n more $_ processes than desired");
            } else {
                $tostart{$_} = $n;
            }
        }

        foreach (keys %tostart) {
            for (my $i = 0; $i < $tostart{$_}; ++$i) {
                my $pid = fork();
                if (!defined($pid)) {
                    print_log('err', "fork: $!");
                } elsif ($pid == 0) {
                    # Restore previous signal handlers.
                    foreach (keys %oldSIG) {
                        POSIX::sigaction($_, $oldSIG{$_});
                    }
                    # Don't leave SIGCHLD blocked in the child.
                    POSIX::sigprocmask(POSIX::SIG_UNBLOCK, $schld);
                    try {
                        &{$spec->{$_}->[1]}();
                    } catch Error with {
                        my $E = shift;
                        print_log('err', "$_ process failed with error $E");
                        exit(1);
                    };
                    exit(0);
                } else {
                    print_log('info', "started new $_ child process, PID $pid");
                    $processes{$pid} = [$_, time()];
                    $count{$_}++;
                }
            }
        }
        
        POSIX::sigprocmask(POSIX::SIG_UNBLOCK, $schld);

        # Why can't we just call waitpid here? Well, in perl < 5.7.3, we could.
        # Previously perl had the usual behaviour over signals: arrival of a
        # signal would cause system calls to return with EINTR. However, since
        # perl 5.7.3, it supports "deferred signals", which are intended to
        # make perl signal handling safe (presumably, by running signal
        # handlers synchronously). As part of this change the maintainers
        # decided that some system calls would be interruptible, and some would
        # not (see perlipc(3)). One of the calls which is no longer restartable
        # is wait(2). So we can't just call wait here, since then the loop
        # would hang for ever. Instead, call waitpid in a loop to collect
        # expired children, and then sleep. Hopefully, signals will interrupt
        # sleep, but just in case, don't sleep for too long....
        while ((my $terminated = waitpid(-1, WNOHANG)) > 0) {
            POSIX::sigprocmask(POSIX::SIG_BLOCK, $schld);

            if (exists($processes{$terminated})) {
                my ($type, $start) = @{$processes{$terminated}};
                my $how = undef;
                if ($? & 127) {
                    $how = 'was killed by signal ' . ($? & 127);
                } elsif ($? >> 8) {
                    $how = 'exited with error status ' . ($? >> 8);
                }
                if ($how) {
                    print_log('err', "$type process PID $terminated $how");
                } else {
                    print_log('info', "$type process PID $terminated normally");
                }

                if ($start > time() - 10) {
                    print_log('err', "child $type process PID $terminated lived for only " . (time() - $start) . " seconds; holding off before restarting it");
                    # Really we should set a deadline and go through the loop,
                    # rather than blocking in sleep here. But this will do....
                    sleep(5);
                }

                --$count{$processes{$terminated}->[0]};
                if ($count{$type} < 0) {
                    print_log('warn', "oops: we seem to have $count{$type} $type processes");
                    $count{$type} = 0;
                }
                delete $processes{$terminated};
            }   # else oops -- we caught a child process we oughtn't to have.
                # Strictly we should only wait for processes we've started,
                # but it's unlikely to matter much in this case.
            
            POSIX::sigprocmask(POSIX::SIG_UNBLOCK, $schld);
        }

        sleep(5);
    }

    print_log('info', "caught signal $foad");
    foreach (keys %processes) {
        POSIX::kill($_, POSIX::SIGTERM);
    }
    
    # XXX at this point we should wait for the processes to terminate

    foreach (keys %oldSIG) {
        POSIX::sigaction($_, $oldSIG{$_});
    }

    return $foad;
}

=item is_valid_postcode STRING

Is STRING (once it has been converted to upper-case and spaces removed) a valid
UK postcode? (As defined by BS7666, apparently.)

=cut
sub is_valid_postcode ($) {
    my $pc = uc($_[0]);
    $pc =~ s#\s##g;

    # Our test postcode
    return 1 if $pc =~ m/^ZZ99Z[ZY]$/;
    
    # See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    my $in  = 'ABDEFGHJLNPQRSTUWXYZ';
    my $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    my $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    my $thd = 'ABCDEFGHJKSTUW';
    my $fth = 'ABEHMNPRVWXY';

    return 1 if (  $pc =~ m#^[$fst]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d\d\d[$in][$in]$#
                || $pc =~ m#^[$fst]\d[$thd]\d[$in][$in]$#
                || $pc =~ m#^[$fst][$sec]\d[$fth]\d[$in][$in]$#);
    return 0;
}

=item is_valid_partial_postcode STRING

Is STRING (once it has been converted to upper-case and spaces removed) a valid
first part of a UK postcode?  e.g. WC1

=cut
sub is_valid_partial_postcode ($) {
    my $pc = uc($_[0]);
    $pc =~ s#\s##g;

    # Our test postcode
    return 1 if $pc eq 'ZZ9';
    
    # See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
    my $fst = 'ABCDEFGHIJKLMNOPRSTUWYZ';
    my $sec = 'ABCDEFGHJKLMNOPQRSTUVWXY';
    my $thd = 'ABCDEFGHJKSTUW';
    my $fth = 'ABEHMNPRVWXY';
  
    return 1 if ($pc =~ m#^[$fst]\d$#
                || $pc =~ m#^[$fst]\d\d$#
                || $pc =~ m#^[$fst][$sec]\d$#
                || $pc =~ m#^[$fst][$sec]\d\d$#
                || $pc =~ m#^[$fst]\d[$thd]$#
                || $pc =~ m#^[$fst][$sec]\d[$fth]$#);
    return 0;
}

=item ordinal NUM

Return the ordinal for NUM (e.g. "1st", "2nd", etc.). XXX localisation.

=cut
sub ordinal ($) {
    my $num = shift;
    if ($num == 11 || $num == 12) {
        return "${num}th";
    } else {
        my $n = $num % 10;
        my @ending = qw(th st nd rd);
        if ($n < @ending) {
            return $num . $ending[$n];
        } else {
            return "${num}th";
        }
    }
}

=item is_valid_email ADDRESS

Restricted syntax-check for ADDRESS. We check for what RFC2821 calls a
"mailbox", which is "local-part@domain", with the restriction of no
address-literal domains (e.g "[127.0.0.1]"). We also don't do bang paths.

=cut
sub is_valid_email ($) {
    my $addr = shift;
    our $is_valid_address_re;

    # This is derived from the grammar in RFC2822.
    if (!defined($is_valid_address_re)) {
        # mailbox = local-part "@" domain
        # local-part = dot-string | quoted-string
        # dot-string = atom ("." atom)*
        # atom = atext+
        # atext = any character other than space, specials or controls
        # quoted-string = '"' (qtext|quoted-pair)* '"'
        # qtext = any character other than '"', '\', or CR
        # quoted-pair = "\" any character
        # domain = sub-domain ("." sub-domain)* | address-literal
        # sub-domain = [A-Za-z0-9][A-Za-z0-9-]*
        # XXX ignore address-literal because nobody uses those...

        my $specials = '()<>@,;:\\\\".\\[\\]';
        my $controls = '\\000-\\037\\177';
        my $highbit = '\\200-\\377';
        my $atext = "[^$specials $controls$highbit]";
        my $atom = "$atext+";
        my $dot_string = "$atom(\\s*\\.\\s*$atom)*";
        my $qtext = "[^\"\\\\\\r\\n$highbit]";
        my $quoted_pair = '\\.';
        my $quoted_string = "\"($qtext|$quoted_pair)*\"";
        my $local_part = "($dot_string|$quoted_string)";
        my $sub_domain = '[A-Za-z0-9][A-Za-z0-9-]*';
        my $domain = "$sub_domain(\\s*\\.\\s*$sub_domain)*";

        $is_valid_address_re = "^$local_part\\s*@\\s*$domain\$";
    }
    
    if ($addr =~ m#$is_valid_address_re#) {
        return 1;
    } else {
        return 0;
    }
}

=item create_accessor_methods 

For a package which is derived from "fields", create any accessor methods which
have not already been defined.

=cut
sub create_accessor_methods () {
    my $h = fields::new((caller())[0]);
    my $caller = caller();
    foreach (keys %$h) {
        
        next if (eval "exists($_)");
        eval <<EOF;
package $caller; 
sub $_ (\$;\$) {
    my \$self = shift;
    if (\@_) {
        \$self->{$_} = \$_[0];
    }
    return \$self->{$_};
}
EOF
    }
}

=item create_file_to_replace FILE

Create a file to replace the named FILE. Returns in list context the name of
the new file, and a handle open on it.

XXX this is inconsistent compared to named_tempfile -- should fix.

=cut
sub create_file_to_replace ($) {
    my ($name) = @_;

    my $st = stat($name);
    my ($v, $path, $file) = File::Spec->splitpath($name);

    for (my $i = 0; $i < 10; ++$i) {
        my $n = File::Spec->catpath($v, $path, sprintf('.%s.%08x.%08x', $file, int(rand(0xffffffff)), time()));
        my $h = new IO::File($n, O_CREAT | O_EXCL | O_WRONLY, defined($st) ? $st->mode() : 0600);
        last if (!$h and !$!{EEXIST});
        return ($n, $h);
    }
    die $!;
}

=item kill_named_processes SIGNAL PGREP_PARAMS

Sends signal SIGNAL to all processes which pgrep(1) matches. PGREP_PARAMS is
the extra parameters for pgrep and will be passed to the shell, so must be
escaped. Parameters to limit pgrep to processes owned by the owner of 
the current process are added to the call to pgrep.

e.g. kill_named_processes(SIGTERM, '"^ref-sign.cgi$"')

=cut
sub kill_named_processes ($$) {
    my ($signal, $pgrep_params) = @_;
    my $uuid = getuid();
    die  "too dangerous to call kill_named_processes as root" if ($uuid == 0);
    $_ = `pgrep -u $uuid $pgrep_params`;
    my @pids = split;
    #print Dumper(\@pids);
    kill $signal, @pids;
}

=item shell COMMAND PARAMS...

Execute given command using "system", and check for an error. If there
is an error, die with useful diagnostics.

=cut
sub shell {
    system(@_);
    if ($?) {
        die "in " . getcwd() . ": " . join(" ", @_) . ": "
            . mySociety::Util::describe_waitval($?, "system");
    }
}


=item describe_waitval VALUE [FUNCTION]

Given VALUE, returned by one of the wait syscalls or system, return undef if
it indicates a successful, normal exit, or a string describing the error
encountered. This will be one of,

=over 4

=item FUNCTION: ERROR

if the system call itself failed;

=item killed by signal NUMBER

if the process was killed by a signal; or

=item exited with status STATUS

if the process exited with a nonzero exit status.

=back

FUNCTION should specify the name of the function which returned VALUE. It
defaults to "wait".

=cut
sub describe_waitval ($;$) {
    my ($value, $fn) = @_;
    $fn ||= 'wait';
    if (!defined($value) || $value == -1) {
        my $e = $!;
        $e ||= 'Unknown error';
        return "$fn: $e";
    } elsif ($value == 0) {
        return undef;
    } elsif ($value & 127) {
        return "$fn: killed by signal " . ($value & 127);
    } else {
        return "$fn: exited with status " . ($value >> 8);
    }
}

=item binomial_confidence_interval SUCCESSES SAMPLES

Returns the mean probability for one trial and its 95% confidence interval,
given the result of a particular series of bernoulli trials. SAMPLES is the
total number of trials, and SUCCESSES is the number that resulted in true.
Return values are (mean, low, high).

So, for example, these two series of trials have the same mean, but a different
confidence interval, because the latter has more samples.

  3 /   10: mean = 0.300000; 95% CI = [0.066739, 0.652454]
300 / 1000: mean = 0.300000; 95% CI = [0.271728, 0.329452]

=cut
sub binomial_confidence_interval ($$) {
    my ($x, $N) = @_;

    die "number of SAMPLES, $N, must be > 0" unless ($N > 0);
    die "number of SUCCESSES, $x, must be >= 0" if ($x < 0);
    die "number of SUCCESSES, $x must be <= SAMPLES, $N" if ($x > $N);

    # If n p q is large, use the normal approximation.
    my $p = $x / $N;
    return ($p, $p - sqrt($p * (1 - $p) / $N), $p + sqrt($p * (1 - $p) / $N))
        if ($N * $p * (1 - $p) > 25);

    # Otherwise we do it properly.

    # http://www.statsresearch.co.nz/pdf/confint.pdf
    # Non Asymptotic Binomial Confidence Intervals
    # x successes from N trials; print estimate of mean and 95% confidence
    # interval.
    my $alpha = 0.05;

    my $mean = ($x / $N);

    if ($x == 0 || $x == $N) {
        # One-sided; see note in http://m2.aol.com/johnp71/confint.html
        $alpha *= 2;
    }

    my $lower;
    if ($x == 0) {
        $lower = 0;
    } else {
        $lower = $x
                    / ($x + ($N - $x + 1) * fdistr(2 * ($N - $x + 1), 2 * $x, $alpha / 2));
    }

    my $upper;
    if ($x == $N) {
        $upper = 1;
    } else {
        $upper = (($x + 1) * fdistr(2 * ($x + 1), 2 * ($N - $x), $alpha / 2))
                    / ($N - $x + ($x + 1) * fdistr(2 * ($x + 1), 2 * ($N - $x), $alpha / 2));
    }

    #printf "%d / %d: mean = %f; 95%% CI = [%f, %f]\n", $x, $N, $mean, $lower, $upper;
    return ($mean, $lower, $upper);
}

=item ms_make_clickable TEXT

Returns TEXT with obvious links made into HTML hrefs. 

Taken from WordPress via mysociety/phplib/utility.php, tweaked slightly to work
with , and . at end of some URLs.

=cut
sub ms_make_clickable {
    my ($ret) = @_;
    my $contract = 1;

    $ret = ' ' . $ret . ' ';
    $ret =~ s#(https?)://([^\s<>{}()]+[^\s.,<>{}()])#<a href='$1://$2' rel='nofollow'>$1://$2</a>#ig;
    $ret =~ s#(\s)www\.([a-z0-9\-]+)((?:\.[a-z0-9\-\~]+)+)((?:/[^ <>{}()\n\r]*[^., <>{}()\n\r])?)#$1<a href='http://www.$2$3$4' rel='nofollow'>www.$2$3$4</a>#ig;
    if ($contract) {
        $ret =~ s#(<a href='[^']*'>)([^<]{40})[^<]*?</a>#$1$2...</a>#g;
    }
    $ret =~ s#(\s)([a-z0-9\-_.]+)@([^,< \n\r]*[^.,< \n\r])#$1<a href=\"mailto:$2@$3\">$2@$3</a>#gi;
    
    # trim
    $ret =~ s#^\s+##;
    $ret =~ s#\s+$##;
    return $ret;
}

=item nl2br TEXT

Returns TEXT with newlines converted to <br>.

Implementation of nl2br in PHP.
=cut
sub nl2br {
    my ($ret) = @_;
    $ret =~ s/\r\n/\n/g;
    $ret =~ s#\n#<br />\n#g;
    return $ret;
}


1;
