#!/usr/bin/perl
#
# mySociety/Config.pm:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Config.pm,v 1.2 2004-10-06 16:38:19 chris Exp $
#

package mySociety::Config;

use strict;
use IO::File;

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
                    
                    ('.+?'|".+?"|\d+)

                    \s*
                    \)
                    #xg) {
        my ($key, $val) = ($1, $2);
        fixup($key);
        fixup($val);
        $config->{$key} = $val;
    }

    return $config;

}



1;
