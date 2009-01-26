#!/usr/bin/perl -w
#
# mySociety/HandleMail.pm
# Functions for dealing with incoming mail messages
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

my $rcsid = ''; $rcsid .= '$Id: HandleMail.pm,v 1.4 2009-01-26 14:21:52 matthew Exp $';

package mySociety::HandleMail;

use strict;
require 5.8.0;

use Mail::Address;
use Mail::Internet;
use MIME::Parser;
use mySociety::SystemMisc;

# Don't print diagnostics to standard error, as this can result in bounce
# messages being generated (only in response to non-bounce input, obviously).
mySociety::SystemMisc::log_to_stderr(0);

sub get_message {
    my @lines = ();
    my $is_bounce_message = 0;
    while (defined($_ = STDIN->getline())) {
        chomp;
        # Skip any From_ line-- we don't need it. BUT, on some systems (e.g.
        # FreeBSD with default exim config), there will be no Return-Path in a
        # message even at final delivery time. So use the insanely ugly
        # "From MAILER-DAEMON ..." thing to distinguish bounces, if it is present.
        if (@lines == 0 and m#^From #) {
            $is_bounce_message = 1 if (m#^From MAILER-DAEMON #);
        } else {
            push(@lines, $_);
        }
    }
    exit 75 if STDIN->error(); # Failed to read it; should defer.

    my $m = new Mail::Internet([@lines]);
    exit 0 unless defined $m; # Unable to parse message; should drop.

    my $return_path;
    if (!$is_bounce_message) {
        # RFC2822: 'The "Return-Path:" header field contains a pair of angle
        # brackets that enclose an optional addr-spec.'
        $return_path = $m->head()->get("Return-Path");
        if (!defined($return_path)) {
            # No Return-Path; we're screwed.
	    exit 0;
        } elsif ($return_path =~ m#<>#) {
            $is_bounce_message = 1;
        } else {
            # This is not a bounce message.
        }
    }

    return ( is_bounce_message => $is_bounce_message, lines => \@lines,
        message => $m, return_path => $return_path );
}

# Get the recipient of a Mail::Internet message
sub get_bounce_recipient {
    my $m = shift;

    my $to = $m->head()->get("To");
    exit 0 unless defined($to); # Not a lot we can do without an address to parse.

    my ($a) = Mail::Address->parse($to);
    exit 0 unless defined($a); # Couldn't parse first To: address.
    
    return $a;
}

# Get the From of a Mail::Internet message
sub get_bounce_from {
    my $m = shift;

    my $from = $m->head()->get('From');
    exit 0 unless defined $from; # No From header

    my ($a) = Mail::Address->parse($from);
    exit 0 unless defined $a; # Couldn't parse From header
    
    return $a;
}

# Checks and returns the user part of the address given, ignoring the prefix
sub get_token {
    my ($a, $prefix, $domain) = @_;
    exit(0) if ($a->user() !~ m#^\Q$prefix\E# or lc($a->host()) ne lc($domain));
    # NB we make no assumptions about the contens of the token.
    my ($token) = ($a->user() =~ m#^\Q$prefix\E(.*)#);
    #print "token $token\n";
    return $token;
}

# parse_dsn_bounce TEXT
# Attempt to parse TEXT (scalar or reference to list of lines) as an RFC1894
# delivery status notification email. On success, return the DSN status string
# "x.y.z" (class, subject, detail). On failure (when TEXT cannot be parsed)
# return undef.
sub parse_dsn_bounce ($) {
    my $P = new MIME::Parser();
    $P->output_to_core(1);  # avoid temporary files when we can

    my $ent = $P->parse_data(join("\n", @{$_[0]}) . "\n");

    return undef if (!$ent || !$ent->is_multipart() || lc($ent->mime_type()) ne 'multipart/report');
    # The second part of the multipart entity should be of type
    # message/delivery-status.
    my $status = $ent->parts(1);
    return undef if (!$status || lc($status->mime_type()) ne 'message/delivery-status');

    # The status is given in an RFC822-format header field within the body of
    # the delivery status message.
    my $h = $status->bodyhandle()->open('r');

    my $r;
    while (defined($_ = $h->getline())) {
        chomp();
        if (/^Status:\s+(\d\.\d+\.\d+)\s*$/) {
            $r = $1;
            last;
        }
    }
    $h->close();

    return $r;
}

