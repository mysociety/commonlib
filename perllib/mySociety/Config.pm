#!/usr/bin/perl
#
# mySociety/Config.pm:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org/

package mySociety::Config;

use strict;

use IO::Handle;
use IO::Pipe;
use Error qw(:try);
use Data::Dumper;
use POSIX ();
use YAML ();

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

my $php_path;

# find_php
# Try to locate the PHP binary in various sensible places.
sub find_php () {
    $ENV{PATH} ||= '/bin:/usr/bin';
    foreach my $dir (split(/:/, $ENV{PATH}),
        qw(/usr/local/bin /usr/bin /software/bin /opt/bin /opt/php/bin)) {
        foreach my $name (qw(php php-cgi)) {
            return "$dir/$name" if (-x "$dir/$name");
        }
    }
    throw Error::Simple "unable to locate PHP binary, needed to read config file";
}

# read_config_from_yaml
# Read configuration data from the named YAML configuration file
sub read_config_from_yaml($) {
    my ($f) = @_;

    open my $fh, "<", $f or throw Error::Simple "$f: failed to open config file: $!";
    my $file_contents = join("", <$fh>);
    my $conf = YAML::Load($file_contents);

    if (ref($conf) ne "HASH") {
        throw Error::Simple "$f: The YAML file must represent an object (a.k.a. hash, dict, map)";
    }

    close $fh;
    return $conf;
}

# read_config_from_php
# Read configuration data from the named PHP configuration file
sub read_config_from_php($) {
    my ($f) = @_;

    if (! -r $f) {
        throw Error::Simple "$f: permission denied trying to read config file (maybe you're not running as the correct user?)";
    }

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
    throw Error::Simple "fork: $!" unless (defined($pid));
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

        exec($php_path) or throw Error::Simple "$php_path: exec: $!";
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
            throw Error::Simple "$php_path: $f: $!";
        } else {
            throw Error::Simple "$php_path: $f: no option output from subprocess";
        }
    }

    # read remainder
    my $buf = join('', $outr->getlines());
    $outr->close();
    my @vals = split(/\0/, $buf, -1); # option values may be empty
    pop(@vals); # The buffer ends "\0" so there's always a trailing empty value
                # at the end of the buffer. I love perl! Perl is my friend!

    throw Error::Simple "$php_path: $f: bad option output from subprocess" if (scalar(@vals) % 2);
    
    waitpid($pid, 0);

    if ($?) {
        if ($? & 127) {
            throw Error::Simple "$php_path: killed by signal " . ($? & 127);
        } else {
            throw Error::Simple "$php_path: exited with failure status " . ($? >> 8);
        }
    }

    # Restore signal handler.
    $old_SIGCHLD ||= 'DEFAULT';
    $SIG{CHLD} = $old_SIGCHLD;

    my %config = @vals;
    return \%config;
}

=item read_config FILE [DEFAULTS]

Read configuration from FILE.

If the filename contains .yml, or FILE.yml exists, that file is parsed as
a YAML object which is returned. Otherwise FILE is parsed by PHP, and any defines
are extracted as config values.

For PHP configuration files only, "OPTION_" is removed from any names
beginning with that.

If specified, values from DEFAULTS are merged.

=cut
sub read_config ($;$) {
    my ($f, $defaults) = @_;

    my $config;
    if ($f =~ /\.yml/) {
        $config = read_config_from_yaml($f);
    } elsif (-f "$f.yml") {
        if (-e $f) {
            throw Error::Simple "Configuration error: both $f and $f.yml exist (remove one)";
        }
        $config = read_config_from_yaml("$f.yml");
    } else {
        $config = read_config_from_php($f);
    }
    if ($defaults) {
        $config->{$_} = $defaults->{$_} foreach (keys %$defaults);
    }

    $config->{"CONFIG_FILE_NAME"} = $f;

    return $config;
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
    throw Error::Simple "Please call mySociety::Config::set_file to specify config file" if (!defined($filename));

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
        throw Error::Simple "No value for '$key' in '" . $config->{'CONFIG_FILE_NAME'} .  "', and no default specified";
    }
}

sub get_list {
    my (%searches) = @_;
    # example of usage get_list('startswith' => 'SMS');
    # returns a ref to a hash of config values
    my $config = load_default();
    my $regexp = '';

    if ($searches{'startswith'}) {
        $regexp = qr/^$searches{'startswith'}/;
    }
    if ($searches{'endswith'}) {
        $regexp = qr/$searches{'endswith'}$/;
    }
    
    if ($regexp) {
        my $conf_subset = {};
        foreach my $key (keys %$config) {
            if ($key =~ $regexp) {
                $conf_subset->{$key} = $config->{$key};
            }
        }
        return $conf_subset;
    } else {
        return $config;
    }
    return {};
}

=item test_run/set

set allows you to change config variables at runtime. As this shouldn't
normally be allowed, and is only for the test suites, you have to call a
special function test_run first, to confirm you want to do this. set
then works as you'd expect, but must come after at least one get.

=cut
my $test_run;
sub test_run() {
    $test_run = 1;
}

sub set($$) {
    return unless $test_run;
    my ($key, $value) = @_;
    $cached_configs{$main_config_filename}{$key} = $value;
}

1;
