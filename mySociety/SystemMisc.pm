#!/usr/bin/perl
#
# mysociety/SystemMisc.pm:
# System, daemons, logging utilities, split from mySociety::Util
#

package mySociety::SystemMisc;

use strict;

use POSIX;
use IO::Handle;
use Sys::Syslog;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&open_log &print_log &printf_log &shell &describe_waitval);
}
our @EXPORT_OK;

=head1 NAME

mySociety::SystemMisc

=head1 DESCRIPTION

System, daemons, logging utilities, split from mySociety::Util.

=head1 FUNCTIONS

=over 4

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

# XXX remove this function, no longer used in E Petitions. Too complicated
# for me to get it to work reliably. Used elsewhere?
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
            . describe_waitval($?, "system");
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

1;


