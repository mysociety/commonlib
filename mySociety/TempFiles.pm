#!/usr/bin/perl
#
# mySociety/TempFiles.pm:
# Utilities for temporary files and filtering, split from mySociety::Utils.

package mySociety::TempFiles;

use strict;

use Fcntl;
use IO::File;
use POSIX ();

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&named_tempfile &tempdir &tempdir_cleanup &pipe_via &create_file_to_replace);
}
our @EXPORT_OK;

=head1 NAME

mySociety::TempFiles;

=head1 DESCRIPTION

Utilities for temporary files and filtering, split from mySociety::Utils.

=head1 FUNCTIONS

=over 4

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

1;
