#!/usr/bin/perl
#
# mySociety/Config.pm:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Config.pm,v 1.5 2004-11-10 12:18:19 chris Exp $
#

package mySociety::Config;

use strict;
use IO::File;
use Error qw(:try);
use Data::Dumper;

sub fixup ($) {
    if ($_[0] =~ m#^'(.+)'$#) {
        $_[0] = $1;
    } elsif ($_[0] =~ m#^"(.+)"$#) {
        $_[0] = $1;
        $_[0] =~ s#\\(.)#$1#g;
    }
}

=item read_config FILE [DEFAULTS]

Read configuration from FILE, which may be either a name or a filehandle.
Returns a reference to a hash of parameter to value. Config files are in a
sort of cod-PHP; basically only define('...', '...') is handled, though we
do process comments. If specified, values from DEFAULTS are merged.

=cut
sub read_config ($;$) {
    my ($f, $defaults) = @_;

    if (!ref($f)) {
        my $F = new IO::File($f, O_RDONLY) or die "$f: $!";
        $f = $F;
    }

    my $text = join('', $f->getlines());
    $f->close();

    $text =~ s#//.*$##m;
    $text =~ s#/\*.+?\*/##s;

    my $config = { };
    if ($defaults) {
        $config->{$_} = $defaults->{$_} foreach (keys %$defaults);
    }

    while ($text =~ m#
                    define
                    \s*
                    \(
                    \s*
                    
                    ('.+?'|".+?")
                    
                    \s*
                    ,
                    \s*
                    
                    ('.*?'|".*?"|\d+)

                    \s*
                    \)
                    #xg) {
        my ($key, $val) = ($1, $2);
        fixup($key);
        fixup($val);
        $key =~ s/^OPTION_//;
        $config->{$key} = $val;
    }

    return $config;
}

=item set_file FILENAME

Sets the default configuration file, used by mySociety::Config::get.

=cut

my $main_config_filename;

sub set_file ($) {
    ($main_config_filename) = @_;
}

=item get KEY [DEFAULT]

Returns the constants set for KEY from the configuration file specified in
set_config_file. The file is automatically loaded and cached. An exception is
thrown if the value isn't present and no DEFAULT is specified.

=cut
my %cached_configs;
sub get ($;$) {
    my ($key, $default) = @_;

    my $filename = $main_config_filename;
    die "Please call mySociety::Config::set_file to specify config file" if (!defined($filename));

    if (!defined($cached_configs{$filename})) {
        $cached_configs{$filename} = read_config($filename);
    }
    
    if (exists($cached_configs{$filename}->{$key})) {
        return $cached_configs{$filename}->{$key};
    } elsif (@_ == 2) {
        return $default;
    } else {
        die "No value for '$key' in $main_config_filename, and no default specified";
    }
}

1;
