#!/usr/bin/perl
#
# mySociety/Logfile/ErrorLog.pm:
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: ErrorLog.pm,v 1.1 2005-01-28 19:05:12 chris Exp $
#

package mySociety::Logfile::ErrorLog;

@mySociety::Logfile::ErrorLog::ISA = qw(mySociety::Logfile);

=head1 NAME

mySociety::Logfile::ErrorLog

=head1 DESCRIPTION

mySociety::Logfile class representing an apache error log file.

=head1 FUNCTIONS

=over 4

=cut

use DateTime;
use DateTime::Format::Strptime;

my $parser = new DateTime::Format::Strptime(
                        pattern => '%a %b %d %H:%M:%S %Y'
                    );

@mySociety::Logfile::ErrorLog::fields = ( time => 'Time', sev => 'Severity', client => 'Client IP', text => 'message');

=item new FILE

Constructor; FILE is the name of an apache error log.

=cut
sub new ($$) {
    my ($class, $file) = @_;
    $self = new mySociety::Logfile($file);
    $self->{fields} = \@mySociety::Logfile::ErrorLog::fields;
    return bless($self, $class);
}

sub parse ($$) {
    my ($self, $line) = @_;
    if (my ($when, $sev, $client, $text) = ($line =~ m#^\[([A-Z][a-z]{2} [A-Z][a-z]{2} +\d+ \d\d:\d\d:\d\d \d{4})\] \[([a-z]+)\] (?:\[client ([^\]]+)\] |)(.*)#)) {
        if (my $time = $parser->parse_datetime($when)) {
            my $f = {
                    time => $time,
                    sev => $sev,
                    text => $text
                };
            $f->{client} = $client if (length($client) > 0);
            return $f;
        }
    }
    
    return { text => $line };
}

1;
