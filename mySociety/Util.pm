#!/usr/bin/perl
#
# mySociety/Util.pm:
# Various miscellaneous utilities.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Util.pm,v 1.31 2005-11-16 17:18:09 chris Exp $
#

package mySociety::Util::Error;

@mySociety::Util::Error::ISA = qw(Error::Simple);

package mySociety::Util;

use strict;

use Errno;
use Error qw(:try);
use Fcntl;
use Getopt::Std;
use IO::File;
use IO::Handle;
use IO::Pipe;
use Net::SMTP;
use POSIX ();
use Sys::Syslog;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&print_log &random_bytes &ordinal &is_valid_email &is_valid_postcode);
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
    do {
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
        exec($prog, @args);
        exit(1);
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
my $logopen;
sub open_log ($) {
    Sys::Syslog::setlogsock('unix');    # Sys::Syslog is nasty
    openlog($_[0], 'pid,ndelay', 'daemon');    
    $logopen = $_[0];
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

Log TEXT to the system log (under PRIORITY) and to standard error. Designed for
use from daemons etc; web scripts should just log to standard error.

=cut
sub print_log ($$) {
    if (!defined($logopen)) {
        my $tag = $0;
        $tag =~ s#^.*/##;
        open_log($tag);
    }
    my ($pri, @a) = @_;
    my $str = join('', @a);
    chomp($str);
    STDERR->print("$logopen: ", $str, "\n") if ($logtostderr);
    syslog($pri, '%s', $str);
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
    return 1 if $pc eq 'ZZ99ZZ';
    
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

=item symbolic_permissions MODE TEXT

Apply to the pre-existing file MODE the permissions changes described by TEXT,
which is a chmod(1)-style symbolic permissions description (e.g.,
"u=rwx,g=r,o-rwx" represents 0710). Returns undef if the string is not a valid
symbolic mode. Does not honour the process's current umask.

=cut
sub symbolic_permissions ($$) {
    my ($mode, $symbolic) = @_;

    #
    # The syntax is defined here:
    #   http://www.opengroup.org/onlinepubs/009695399/utilities/chmod.html
    # This function is trivially derived from one in,
    #   http://ppt.perl.org/commands/chmod/SymbolicMode.pm
    # but that version is not separately packaged and only operates on files,
    # whereas we want one which operated on mode integers. It also honours the
    # umask, whereas we do not.
    #

    # Initialization.
    # The 'user', 'group' and 'other' groups.
    my @ugo          = qw/u g o/;
    # Bit masks for '[sg]uid', 'sticky', 'read', 'write' and 'execute'.
    # Can't use qw // cause silly Perl doesn't know '2' is a number
    # when dealing with &= ~$bit.
    my %bits         = (s => 8, t => 8, r => 4, w => 2, x => 1);

    # For parsing.
    my $who_re       = '[augo]*';
    my $action_re    = '[-+=][rstwxXugo]*';

    # Find the current permissions. This is what we start with.
    $mode            = sprintf('%04o', $mode);
    my $current      = substr($mode, -3);  # rwx permissions for ugo.

    my %perms;
    @perms{@ugo} = split(//, $current);

    # Handle the suid, guid and sticky bits.
    #
    # It looks like permission are 4 groups of 3 bits, groups for user, group
    # and others, and a group for the special flags, but they are really 3
    # groups of 4 bits. Or maybe not. 
    #
    # Anyway, this function is greatly simplified by treating them as 3 4-bit
    # groups. The highest bit will be "special" one. suid for the users group,
    # guid for the group group, and the sticky bit for the others group.
    my $special      = substr($mode, 0, 1);
    my $bit          = 1;
    foreach my $c (reverse @ugo) {
        $perms{$c} |= 8 if ($special & $bit);
        $bit <<= 1;
    }

    # Keep track of the original permissions.
    my %orig         = %perms;

    # Time to parse...
    foreach my $clause (split(/,/, $symbolic)) {
        # Perhaps we should die if we can't parse it?
        return undef unless
            my ($who, $actions) =
            $clause =~ /^($who_re)((?:$action_re)+)$/o;

        # We would rather split the different actions out here, but there
        # doesn't seem to be a way to collect them. /^($who_re)($action_re)+/
        # only gets the last one. Now, we have to reparse in later.

        my %who;
        if ($who) {
            $who =~ s/a/ugo/;  # Ignore multiple 'a's.
            @who{split(//, $who)} = undef;
        }

        # @who will contain who these settings applies to. If who isn't set,
        # it might be masked with the umask, hence, this isn't the final
        # decision. Maybe we don't need this.
        # XXX I've stripped out the umask stuff --CWRL
        my @who = $who ? keys(%who) : @ugo;

        foreach my $action (split /(?=$action_re)/o => $actions) {
            # The first character has to be the operator.
            my $operator = substr($action, 0, 1);
            # And the rest are the permissions.
            my $perms    = substr($action, 1);

            # BSD documentation says 'X' is to be ignored unless the operator
            # is '-'. GNU, HP, SunOS and Solaris handle '-' and '=', while
            # OpenBSD ignores only '-'. Solaris, HP and OpenBSD all turn a
            # file with permission 666 to a file with permission 000 if chmod
            # =X is is applied on it. SunOS and GNU act as if chmod = was
            # applied to it. I cannot find out what the reasoning behind the
            # choices of Solaris, HP and OpenBSD is. GNU and SunOS seem to
            # ignore the 'X', which, after careful studying of the
            # documentation seems to be the right choice. Therefore, remove
            # any 'X' if the operator ain't '+';
            $perms =~ s/X+//g unless($operator eq '+');

            # If there are no permissions, things are simple.
            unless ($perms) {
                # Things like u+ and go- are ignored; only = makes sense.
                next unless $operator eq '=';
                # Clear permissions on u= and go=.
                @perms{keys %who} = (0) x 3;
                next;
            }

            # If we arrive here, $perms is a string. We can iterate over the
            # characters.
            foreach (split(//, $perms)) {
                if ($_ eq 'X') {
                    # We know the operator eq '+'.
                    # Permission of `X' is special. If used on a regular file,
                    # the execution bit will only be turned on if any of the
                    # execution bits of the _unmodified_ file are turned on.
                    # That is,
                    #      chmod 600 file; chmod u+x,a+X file;
                    # should result in the file having permission 700, not 711.
                    # GNU and SunOS get this wrong;
                    # Solaris, HP and OpenBSD get it right.
                    # XXX I have modified this not to test whether it's being
                    # applied to a directory, since we don't know --CWRL
                    next unless (grep { $orig{$_} & 1 } @ugo);
                    # Now, do as if it's an x.
                    $_ = 'x';
                }

            if (/[st]/) {
                # BSD man page says operations on 's' and 't' are to be ignored
                # if they operate only on the "other" group.  GNU and HP
                # happely accept 'o+t'. Sun rejects 'o+t', but also rejects
                # 'g+t', accepting only 'u+t'.
                #
                # OpenBSD accepts both 'u+t' and 'g+t', ignoring 'o+t'.  We do
                # too.
                #
                # OpenBSD however, accepts 'o=t', clearing all the bits of the
                # "other" group.
                #
                # We don't, as that doesn't make any sense, and doesn't
                # conform to the documentation.
                next if ($who =~ /^o+$/);
            }

            # Determine the $bit for the mask.
            my $bit = /[ugo]/ ? $orig{$_} & ~8 : $bits{$_};

            die "Weird permission '$_' found\n" unless(defined($bit));
            # Should not happen.

            # Determine the set on which to operate.
            my @set = $who ? @who : @ugo;

            # If the permission is 's', don't operate on the other group.
            # Unless the operator was '='. But in that case, don't set the 8
            # bit for 'other'.
            my $equal_s;
            if (/s/) {
                if ($operator eq '=') {
                    $equal_s = 1;
                } else {
                    @set     = grep {!/o/} @set or next;
                }
            }

            # If the permission is 't', only  operate on the other group;
            # regardless what the 'who' settings are.  Note that for a
            # directory with permissions 1777, and a umask of 002, a chmod =t
            # on HP and Solaris turn the permissions to 1000, GNU and SunOS
            # turn the permissiosn to 1020, while OpenBSD keeps 1777.
            /t/ and @set = qw /o/;

            # Apply.
            foreach my $s (@set) {
                do {$perms{$s} |=  $bit; next} if ($operator eq '+');
                do {$perms{$s} &= ~$bit; next} if ($operator eq '-');
                do {$perms{$s}  =  $bit; next} if ($operator eq '=');
                die "Weird operator '$operator' found\n";
                # Should not happen.
            }

            # Special case '=s'.
            $perms{o} &= ~$bit if $equal_s;
        }
        }
    }

    # Now, translate @perms to a number.

    # First, deal with the suid, guid, and sticky bits by collecting the high
    # bits of the ugo permissions.
    my $first = 0;
    $bit   = 1;
    for my $c (reverse @ugo) {
        if ($perms{$c} & 8) {
            $first |= $bit;
            $perms{$c} &= ~8;
        }
        $bit <<= 1;
    }

    return ($first << 9 | $perms{u} << 6 | $perms{g} << 3 | $perms{o});
}

1;
