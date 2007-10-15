#!/usr/bin/perl
#
# mySociety/Config.pm:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Config.pm,v 1.16 2007-10-15 13:48:54 francis Exp $
#

package mySociety::Config;

use strict;

use IO::Handle;
use IO::Pipe;
use Error qw(:try);
use Data::Dumper;
use POSIX ();

=head1 NAME

mySociety::Config

=head1 SYNOPSIS

    mySociety::Config::set_file('../conf/general');
    my $opt = mySociety::Config::get('CONFIG_VARIABLE', DEFAULT_VALUE);

=head1 DESCRIPTION

Parse config files (written in a sort of cod-php, using

    define(OPTION_VALUE_NAME, "value of option");

to define individual elements.

=head1 FUNCTIONS

=over 4

=cut

# find_php
# Try to locate the PHP binary in various sensible places.
sub find_php () {
    $ENV{PATH} ||= '/bin:/usr/bin';
    foreach my $dir (split(/:/, $ENV{PATH}),
        qw(/usr/local/bin /usr/bin /software/bin /opt/bin /opt/php/bin)) {
        foreach my $name (qw(php4 php php4-cgi php-cgi)) {
            return "$dir/$name" if (-x "$dir/$name");
        }
    }
    die "unable to locate PHP binary, needed to read config file";
}

=item read_config FILE [DEFAULTS]

Read configuration from FILE, which should be the name of a PHP config file.
This is parsed by PHP, and any defines are extracted as config values.
"OPTION_" is removed from any names beginning with that. If specified, values
from DEFAULTS are merged.

=cut
my $php_path;
sub read_config ($;$) {
    my ($f, $defaults) = @_;

    my $old_SIGCHLD = $SIG{CHLD};
    $SIG{CHLD} = sub { };

    # We need to find the PHP binary.
    $php_path ||= find_php();

    # This is a bit miserable. We ought to use IPC::Open2 or similar, but
    # can't because of a nasty interaction with the tied filehandles which
    # FCGI.pm uses.
    my ($inr, $inw, $outr, $outw);
    $inr = new IO::Handle();
    $inw = new IO::Handle();
    $outr = new IO::Handle();
    $outw = new IO::Handle();
    my $p1 = new IO::Pipe($outr, $outw);
    my $p2 = new IO::Pipe($inr, $inw);

    my $pid = fork();
    die "fork: $!" unless (defined($pid));
    if ($pid == 0) {
        # Delete everything from the environment other than our special
        # variable to give PHP the config file name. We don't want PHP to pick
        # up other information from our environment and turn into an FCGI
        # server or something.
        %ENV = ( MYSOCIETY_CONFIG_FILE_PATH => $f );

        $inw->close();
        $outr->close();

        POSIX::close(0);
        POSIX::close(1);
        POSIX::dup2($inr->fileno(), 0);
        POSIX::dup2($outw->fileno(), 1);
        $inr->close();
        $outw->close();

        exec($php_path) or die "$php_path: exec: $!";
    }

    $inr->close();
    $outw->close();

    $inw->print(<<'EOF');
<?php
$b = get_defined_constants();
require(getenv("MYSOCIETY_CONFIG_FILE_PATH"));
$a = array_diff_assoc(get_defined_constants(), $b);
print "start_of_options\n";
foreach ($a as $k => $v) {
    print preg_replace("/^OPTION_/", "", $k); /* strip off "OPTION_" if there */
    print "\0";
    print $v;
    print "\0";
}
?>
EOF

    $inw->close();

    # skip any header material
    my $line;
    while (defined($line = $outr->getline())) {
        last if ($line eq "start_of_options\n");
    }

    if (!defined($line)) {
        if ($outr->error()) {
            die "$php_path: $f: $!";
        } else {
            die "$php_path: $f: no option output from subprocess";
        }
    }

    # read remainder
    my $buf = join('', $outr->getlines());
    $outr->close();
    my @vals = split(/\0/, $buf, -1); # option values may be empty
    pop(@vals); # The buffer ends "\0" so there's always a trailing empty value
                # at the end of the buffer. I love perl! Perl is my friend!

    die "$php_path: $f: bad option output from subprocess" if (scalar(@vals) % 2);

    my %config = @vals;

    if ($defaults) {
        $config{$_} = $defaults->{$_} foreach (keys %$defaults);
    }

    waitpid($pid, 0);

    if ($?) {
        if ($? & 127) {
            die "$php_path: killed by signal " . ($? & 127);
        } else {
            die "$php_path: exited with failure status " . ($? >> 8);
        }
    }

    $config{"CONFIG_FILE_NAME"} = $f;

    # Restore signal handler.
    $old_SIGCHLD ||= 'DEFAULT';
    $SIG{CHLD} = $old_SIGCHLD;

    return \%config;
}

=item set_file FILENAME

Sets the default configuration file, used by mySociety::Config::get.

=cut

my $main_config_filename;

sub set_file ($) {
    ($main_config_filename) = @_;
}

=item load_default

Loads and caches default config file, as set with set_file.  This
function is implicitly called by get and get_all.

=cut
my %cached_configs;
sub load_default() {
    my $filename = $main_config_filename;
    die "Please call mySociety::Config::set_file to specify config file" if (!defined($filename));

    if (!defined($cached_configs{$filename})) {
        $cached_configs{$filename} = read_config($filename);
    }
    return $cached_configs{$filename};
}

=item get KEY [DEFAULT]

Returns the constants set for KEY from the configuration file specified in
set_config_file. The file is automatically loaded and cached. An exception is
thrown if the value isn't present and no DEFAULT is specified.

=cut
sub get ($;$) {
    my ($key, $default) = @_;

    my $config = load_default();
    
    if (exists($config->{$key})) {
        return $config->{$key};
    } elsif (@_ == 2) {
        return $default;
    } else {
        die "No value for '$key' in '" . $config->{'CONFIG_FILE_NAME'} .  "', and no default specified";
    }
}

1;
