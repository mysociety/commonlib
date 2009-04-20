#!/usr/bin/perl -w
#
# mySociety/HandleMail.pm
# Functions for dealing with incoming mail messages
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/

my $rcsid = ''; $rcsid .= '$Id: HandleMail.pm,v 1.7 2009-04-20 13:19:58 louise Exp $';

package mySociety::HandleMail;

use strict;
require 5.8.0;

use Mail::Address;
use Mail::Internet;
use MIME::Parser;
use mySociety::SystemMisc;


use constant ERR_NO_USER => 1;
use constant ERR_NO_RELAY => 2;
use constant ERR_MAILBOX_FULL => 3;
use constant ERR_MAILBOX_UNAVAILABLE => 4;
use constant ERR_UNROUTEABLE => 5;
use constant ERR_TIMEOUT => 6;
use constant ERR_SPAM => 7;
use constant ERR_TEMPORARILY_DEFERRED => 8;
use constant ERR_VERIFICATION_FAILED => 9;
use constant ERR_MESSAGE_REFUSED => 10;

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


# parse_ill_formed_bounce TEXT
# Attempt to extract bounce attributes if the email represented by TEXT is an ill-formed bounce
# email.
sub parse_ill_formed_bounce ($){
    my $lines = shift;
    my $mail = join("\n", @$lines);
    
    my %data = parse_mdn_error($lines);
    if (!$data{message}){
        %data = parse_remote_host_error($mail);
    }
    if (!$data{message}){
        %data = parse_smtp_error($mail);
    }
    if (!$data{message}){
        %data = parse_remote_host_error($mail);
    }
    if (!$data{message}){
        %data = parse_qmail_error($mail);
    }
    if (!$data{message}){
        %data = parse_exim_error($mail);
    }
    return %data;
}

# parse_exim_error TEXT
# parse a bounce error email in standard exim-output format
# and return a hash of attributes 
sub parse_exim_error ($){
    my $text = shift;
    my $domain;
    my $message;
    my $email_address;
    my $permanent = 0;
    my $problem;
    my $main_para_pattern = '\s*\n?\s*                              
                            The\ following\ address\(es\)\ failed:
                            \n\s*\n\s*';
    
    my $message_pattern = '\s*\n
                          (\s*\(.*?generated.*?\)\s*\n)?    #option description of where the address was generated from
                          (.*?)\n';                         # error message
    
    my $email_pattern = '(.*?@(.*?))';
    
    my $standard_text = 'This\ is\ a\ permanent\ error.'
                        . $main_para_pattern 
                        . $email_pattern 
                        . $message_pattern;           
    
    if ($text =~ /$standard_text/x){
        $email_address = $1;
        $domain = $2;
        $message = $4;
        $permanent = 1;
    }
    my $alternative_text = 'of\ its\ recipients.' 
                            . $main_para_pattern 
                            . $email_pattern 
                            . $message_pattern;
    if ($text =~ /$alternative_text/x){
        $email_address = $1;
        $domain = $2;
        $message = $4;
    
    }
    
    if ($message){
        $message = join(' ', split(' ', $message));
        $problem = get_problem_from_message($message);
    }
    
    return (domain => $domain, 
            message => $message, 
            problem => $problem,
            permanent => $permanent, 
            email_address => $email_address);
}

# parse_qmail_error TEXT
# parse a bounce error email in standard qmail-output format
# and return a hash of attributes
sub parse_qmail_error ($){
    my $text = shift;
    my $domain;
    my $message;
    my $email_address;
    my $dsn_code;
    my $problem;
    my $main_para_pattern = 'Hi. This is the qmail-send program.*?\n\s*';
    my $email_pattern = '<(.*@(.*))>:\n';
    my $message_pattern = '((([^\n]*\w+[^\n]*)\n)*)';
    my $standard_text = $main_para_pattern . $email_pattern . $message_pattern;
    if ($text =~ /$standard_text/s){
        $email_address = $1;
        $domain = $2;
        $message = $3;
        $message = join(' ', split(' ', $message));
        if ($message =~ s/ \(#(\d\.\d\.\d)\)$//){
            $dsn_code = $1;
        }
        $problem = get_problem_from_message($message);
    }

    return (domain => $domain, 
            message => $message, 
            problem => $problem,
            dsn_code => $dsn_code, 
            email_address => $email_address);
}

# parse_remote_host_error TEXT
# parse a bounce error email describing the response from a remote host
# and return a hash of attributes
sub parse_remote_host_error ($){
    my $text = shift;
    my $email_address;
    my $domain;
    my $message;
    my $smtp_code;
    my $dsn_code;
    my $problem;
    if ($text =~ /does not like recipient.\n\s*Remote host said: (\d\d\d) (\d\.\d\.\d) <(.*@(.*))>: (.*?)\n/) {
        $smtp_code = $1;
        $dsn_code = $2;
        $email_address = $3;
        $domain = $4;
        $message = $5;
        $problem = get_problem_from_message($message);
    }
    
    return (domain => $domain, 
            smtp_code => $smtp_code, 
            dsn_code => $dsn_code, 
            problem => $problem,
            email_address => $email_address, 
            message => $message);
}

# parse_smtp_error TEXT
# parse a bounce error email in standard SMTP output format
# and return a hash of attributes
sub parse_smtp_error ($){
    my $text = shift;
    my $domain;
    my $message;
    my $smtp_code;
    my $dsn_code;
    my $email_address;
    my $problem;
    my $mail_pattern = '(\S*@(.*?))\s*\n\s*';
    my $smtp_start = 'SMTP error from remote mail(?:er)? (?:server )?after ';
    my $host_pattern = '\s+host [^ ]* \[[^ ]*\]:(?:\n)?';
    my $message_pattern = '(.*?)\n(((.*\S+.*)\n)*)';
    my $error_time_pattern = '(RCPT TO:<.*@.*?>:|end of data:\n|pipelined DATA:\n|initial connection:\n|MAIL FROM:<.*?> SIZE=\d+:)';
    my $error_pattern = $mail_pattern . $smtp_start . $error_time_pattern . $host_pattern . $message_pattern;
 
    if ($text =~ /$error_pattern/){
        $email_address = $1;
        $domain = $2;
        $message = $4 || '';
        if ($5){
            $message .= $5;
        }
        $message = join(' ', split(' ', $message));
        ($message, $dsn_code, $smtp_code) = get_codes_from_message($message);
        $message =~ s/^<.*?>: //;
        $problem = get_problem_from_message($message);
    }
      
    return (domain => $domain, 
            smtp_code => $smtp_code, 
            dsn_code => $dsn_code, 
            email_address => $email_address,
            problem => $problem, 
            message => $message), 
}

# parse_mdn_error TEXT
# Parse an error email in a standard MDN format and return a hash of attributes 
sub parse_mdn_error($){
    my ($lines) = @_;
    
    my $email_address;
    my $domain;
    my ($mdn, $message) = parse_mdn_bounce($lines);
    if ($mdn){
        if ($message =~ /<(.*?@(.*?))>/){
            $email_address = $1;
            $domain = $2;
        }
        my $problem = get_problem_from_message($message);
        return (message => $message, 
                problem => $problem, 
                email_address => $email_address, 
                domain => $domain);
    }else{
        return ();
    }
}

# get_codes_from_message TEXT
# Extract SMTP or DSN error codes from an email error message
# Returns an array of the message (with codes removed), any 
# DSN code, and any SMTP code
sub get_codes_from_message($){
    my ($message) = @_;
    my $dsn_code;
    my $smtp_code;
    if ($message =~ s/^(\d\d\d)( |-)//){
        $smtp_code = $1;
    }
    if ($message =~ s/^(\d\.\d\.\d) //){
        $dsn_code = $1;
    }
    if ($message =~ s/ \(#(\d\.\d\.\d)\)$//){
        $dsn_code = $1;
    }
    return ($message, $dsn_code, $smtp_code);
}

# get_problem_from_message TEXT
# Translate an error message into a problem constant
sub get_problem_from_message($){
    my ($message) = @_;
    my $problem;
    
    my @temporary_deferral_synonyms = ('temporarily deferred');
    my $temporary_deferral_pattern = join('|', @temporary_deferral_synonyms);
    my @no_user_synonyms = ('address rejected',
                            'does not exist', 
                            'email address for typos',
                            'invalid address',
                            'invalid recipient', 
                            'never logged onto their free aim',
                            'no mailbox here by that name', 
                            'no such mailbox',
                            'no such address',
                            'no such recipient',
                            'no such user', 
                            'not a valid mailbox',
                            'recipient unknown',
                            'unable to validate recipient',
                            'unknown recipient',
                            'unknown user', 
                            'unknown (\S+) user',
                            'user invalid',
                            'user (is )?unknown');
    my $no_user_pattern = join('|', @no_user_synonyms);
       
    my @no_relay_synonyms = ('as a relay', 
                             'no valid cert for gatewaying', 
                             'not configured to relay mail',
                             'relay access denied',
                             'relay denied',
                             'relaying denied');
    my $no_relay_pattern = join('|', @no_relay_synonyms);
       
    my @mailbox_full_synonyms = ('mail quota exceeded',
                                 'mailbox disk quota exceeded',
                                 'mailbox has exceeded the limit',
                                 'mailbox is full', 
                                 'mailfolder is over the allowed quota', 
                                 'over quota', 
                                 'quota exceeded',
                                 'recipient overquota', 
                                 'user has exceeded their quota');
    my $mailbox_full_pattern = join('|', @mailbox_full_synonyms);
    
    my @mailbox_unavailable_synonyms = ('mailbox disabled', 
                                        'mailbox inactive', 
                                        'mailbox is disabled',
                                        'mailbox unavailable',
                                        'user account not activated');
    my $mailbox_unavailable_pattern = join('|', @mailbox_unavailable_synonyms);
    
    my @unrouteable_synonyms = ('all relevant mx records point to non-existent hosts', 
                                "domain isn't in my list of allowed rcpthosts",
                                'unrouteable');
    my $unrouteable_pattern = join('|', @unrouteable_synonyms); 
    
    my @timeout_synonyms = ('retry timeout', 
                            'retry time not reached for any host after a long failure period');
    my $timeout_pattern = join('|', @timeout_synonyms); 

    my @spam_synonyms = ('message looks like spam',
                         'high on spam scale',
                         'rejected due to security policies', 
                         'message has been blocked',
                         'this message is unwanted here');
    my $spam_pattern = join('|', @spam_synonyms);
        
    my @verification_failed_synonyms = ('sender verify failed');
    my $verification_failed_pattern = join('|', @verification_failed_synonyms);
    
    my @message_refused_synonyms = ('unable to deliver to');
    my $message_refused_pattern = join('|', @message_refused_synonyms);
    
    if($message =~ /$temporary_deferral_pattern/i){
        $problem = ERR_TEMPORARILY_DEFERRED;
    }elsif($message =~ /$mailbox_full_pattern/i){
        $problem = ERR_MAILBOX_FULL;
    }elsif ($message =~ /$no_user_pattern/i){
        $problem = ERR_NO_USER;
    }elsif($message =~ /$no_relay_pattern/i){
        $problem = ERR_NO_RELAY;
    }elsif($message =~ /$mailbox_unavailable_pattern/i){
        $problem = ERR_MAILBOX_UNAVAILABLE;
    }elsif($message =~ /$unrouteable_pattern/i){
        $problem = ERR_UNROUTEABLE;
    }elsif($message =~ /$timeout_pattern/i){
        $problem = ERR_TIMEOUT;
    }elsif($message =~ /$spam_pattern/i){
        $problem = ERR_SPAM;
    }elsif($message =~ /$verification_failed_pattern/i){
        $problem = ERR_VERIFICATION_FAILED;
    }elsif($message =~ /$message_refused_pattern/i){
        $problem = ERR_MESSAGE_REFUSED;
    }
    
    return $problem;
}

# parse_dsn_bounce TEXT
# Attempt to parse TEXT (scalar or reference to list of lines) as an RFC3798
# message disposition notification email. On success, return the MDN disposition string and
# an error string. On failure (when TEXT cannot be parsed) return undef.
sub parse_mdn_bounce ($) {
    my $P = new MIME::Parser();
     $P->output_to_core(1); 
     my $ent = $P->parse_data(join("\n", @{$_[0]}) . "\n");
     
     return undef if (!$ent || !$ent->is_multipart() || lc($ent->mime_type()) ne 'multipart/report');
     
     # The first part of the multipart entity should be a human-readable explanation of the MDN
     my $message_part = $ent->parts(0);
     my $h = $message_part->bodyhandle()->open('r');
     my $message = '';
     while (defined($_ = $h->getline())) {
          $message .= $_;
      }
     $message = join(' ', split(' ', $message));
     $h->close();
      
     # The second part of the multipart entity should be of type
     # message/disposition-notification.
     my $status = $ent->parts(1);
     return undef if (!$status || lc($status->mime_type()) ne 'message/disposition-notification');
    
     # The disposition message is given in an RFC822-format header field within the body of
     # the delivery status message.
     $h = $status->bodyhandle()->open('r');

     my $r;
     while (defined($_ = $h->getline())) {
         chomp();
         if (/^Disposition:\s+(.*?)\s*$/) {
             $r = $1;
             last;
         }
     }
     $h->close();

     return ($r, $message);
}


# parse_dsn_bounce TEXT
# Attempt to parse TEXT (scalar or reference to list of lines) as an RFC1894
# delivery status notification email. On success, return the DSN status string
# "x.y.z" (class, subject, detail). On failure (when TEXT cannot be parsed)
# return undef.
sub parse_dsn_bounce ($) {
    my $P = new MIME::Parser();

    $P->output_to_core(1);  # avoid temporary files when we can
    # print join("\n", @{$_[0]});
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

