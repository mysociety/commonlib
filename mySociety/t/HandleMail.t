#!/usr/bin/perl -w
#
# HandleMail.t:
# Tests for the HandleMail functions
#
#  Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: HandleMail.t,v 1.1 2009-04-15 14:20:13 louise Exp $
#

use strict;
use warnings; 

use Test::More tests=>4;

# Horrible boilerplate to set up appropriate library paths.
use FindBin;
use lib "$FindBin::Bin/../../../perllib";
#---------------------------------

sub create_test_message($){
    my $message_file = shift;
    open FILE, "<", "examples/" . $message_file or die $!;
    # my @lines = <FILE>;
    my @lines = ();
    my $line;
    while ($line = <FILE>) {
        chomp $line;
        push @lines, $line;
    }
    return @lines;
}

#---------------------------------

sub parse_dsn_bounce($){
    my $message_file = shift;
    my @lines = create_test_message($message_file);
    my $return = mySociety::HandleMail::parse_dsn_bounce(\@lines);
    return $return;
}

#---------------------------------

BEGIN { use_ok('mySociety::HandleMail'); }

sub test_parse_dsn_bounce(){

    my $status = parse_dsn_bounce('aol-mailbox-full.txt');
    is($status, "5.2.2", 'parse_dsn_bounce should return a status of "5.2.2" for a "Mailbox full" bounce from AOL');
    
    $status = parse_dsn_bounce('nhs-user-over-quota.txt');   
    is($status, "5.1.1", 'parse_dsn_bounce should return a status of "5.1.1" for a "User over quota" bounce from the NHS');
    
    return 1;
}

ok(test_parse_dsn_bounce() == 1, 'Ran all tests for parse_dsn_bounce');