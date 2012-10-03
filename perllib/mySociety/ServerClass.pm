#!/usr/bin/perl
#
# mySociety/ServerClass.pm:
# Parse /data/servers/serverclass
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org/

package mySociety::ServerClass;

use strict;

use Data::Dumper;

my $serverclass_file = "/data/servers/serverclass";

=item read_config

Causes reading of serverclass file.

=cut
my $server_to_classes;
my $class_to_servers;
sub read_config() {
    if ($server_to_classes && $class_to_servers) {
        return;
    }

    open(FH, $serverclass_file) or die "Failed to open $serverclass_file: $!";
    while(<FH>) {
        my $line = $_;
        chomp $_;
        next if (m/\s*#/); # comments
        next if (m/^\s*$/); # blank lines
        my ($server, $class) = split m/\s+/, $line;
        push @{$server_to_classes->{$server}}, $class;
        push @{$class_to_servers->{$class}}, $server;
    }
    #print Dumper($server_to_classes);
    #print Dumper($class_to_servers);
}

=item server_in_class SERVER CLASS

Returns 1 if given server is in given class, otherwise 0.

=cut
sub server_in_class($$) {
    my ($server, $class) = @_;

    # Make sure config read
    read_config(); 

    my $classes = $server_to_classes->{$server};
    return 0 if !$classes;

    return (grep { $class eq $_ } @$classes) ? 1 : 0;
}

=item servers_all

Returns list of all servers.

=cut
sub all_servers() {
    # Make sure config read
    read_config(); 

    return keys(%$server_to_classes);
}

=item servers_in_class CLASS

Returns list of all servers in a given class.

=cut
sub all_servers_in_class($) {
    my ($class) = @_;

    # Make sure config read
    read_config(); 

    my $servers = $class_to_servers->{$class};
    return @$servers;
}


1;
