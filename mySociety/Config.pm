#!/usr/bin/perl
#
# mySociety/Config.pm:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Config.pm,v 1.10 2004-11-25 00:10:50 chris Exp $
#

package mySociety::Config;

use strict;
use IO::File;
use IPC::Open2;
use Error qw(:try);
use Data::Dumper;
use POSIX;

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

sub fixup ($) {
    if ($_[0] =~ m#^'(.+)'$#) {
        $_[0] = $1;
    } elsif ($_[0] =~ m#^"(.+)"$#) {
        $_[0] = $1;
        $_[0] =~ s#\\(.)#$1#g;
    }
}

# find_php
# Try to locate the PHP binary in various sensible places.
sub find_php () {
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
This is parsed by PHP, and any defines with names beginning "OPTION_" are
extracted as config values. If specified, values from DEFAULTS are merged.

=cut
my $php_path;
sub read_config ($;$) {
    my ($f, $defaults) = @_;
    # We need to find the PHP binary.
    $php_path ||= find_php();

    # Safest way to pass the value into PHP....

    my ($rd, $wr);
    $ENV{MYSOCIETY_CONFIG_FILE_PATH} = $f;
    my $pid = open2($rd, $wr, $php_path) or die "$php_path: $f: $!";
    delete($ENV{MYSOCIETY_CONFIG_FILE_PATH});

    $wr->print(<<'EOF');
<?php

require(getenv("MYSOCIETY_CONFIG_FILE_PATH"));

$a = get_defined_constants();

print "start_of_options\n";
foreach ($a as $k => $v) {
    if (preg_match("/^OPTION_/", $k)) {
        print substr($k, 7); /* strip off "OPTION_" */
        print "\0";
        print $v;
        print "\0";
    }
}

?>
EOF

    $wr->close();

    # skip any header material
    my $line;
    while (defined($line = $rd->getline())) {
        last if ($line eq "start_of_options\n");
    }

    if (!defined($line)) {
        if ($rd->error()) {
            die "$php_path: $f: $!";
        } else {
            die "$php_path: $f: no option output from subprocess";
        }
    }

    # read remainder
    my $buf = '';
    my $n;
    do {
        $n = $rd->read($buf, 1024, length($buf));
        die "$php_path: $f: $!" if (!defined($n));
    } while ($n > 0);

    $rd->close();

    my @vals = split(/\0/, $buf);
    die "$php_path: $f: bad option output from subprocess" if (scalar(@vals) % 2);

    my %config = @vals;

    if ($defaults) {
        $config{$_} = $defaults->{$_} foreach (keys %$defaults);
    }

    # Wait for PHP to finish. But someone else may have installed a handler for
    # SIGCHLD, so don't try too hard.
    waitpid($pid, POSIX::WNOHANG);

    $config{"CONFIG_FILE_NAME"} = $f;

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
