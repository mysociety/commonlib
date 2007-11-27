#!/usr/bin/perl
#
# mySociety/SMS.pm:
# mySociety SMS send.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email:angie@mysociety.org; WWW: http://www.mysociety.org/
#
my $rcsid = ''; $rcsid .= '$Id: SMS.pm,v 1.2 2007-11-27 15:34:44 angie Exp $';

package mySociety::SMS;

use strict;

use mySociety::SystemMisc qw(print_log);
use LWP::UserAgent;

sub mySociety::SMS::new {
    my ($class, %config) = @_;
    bless {
        _smsmessage => "",
        _to => "",
        _error => "",
        _reponse_messages => "",
        _id => "",
        _sms_url => $config{'url'},
    }, $class;
    
}


# is_valid_number NUMBER
# Is NUMBER a valid SMS recipient?
sub is_valid_number ($) {
    # This tests for a plausible UK number. Could use Number::Phone::UK or a
    # more general service.
    if ($_[0] =~ m#^\+44\d+#) {
        return 1;
    } else {
        return 0;
    }
}

sub check_ia5 {
    my ($class, $message) = @_;
# We need to be able to process messages in the wretched IA5 character set
# which mobile phones apparently speak. This is like ASCII, but with all the
# control codes replaced with random NLS characters in a completely arbitrary
# order.
#

=item check_ia5 TEXT

Verify that TEXT is representable in IA5.

=cut

    my @ia5_to_unicode = (0 .. 127);
    
    @ia5_to_unicode[0 .. 31] = (
            #  0
            0x40, 0xa3, 0x24, 0xa5, 0xe8, 0xe9, 0xf9, 0xec,
            #  8
            0xf2, 0xc7, 0x0a, 0xd8, 0xf8, 0x0d, 0xc5, 0xe5,
            # 10
            0x394, 0x5f, 0x3a6, 0x393, 0x39b, 0x3a9, 0x3a0, 0x3a8,
            # 18
            0x3a3, 0x398, 0x39e, 0x1b, 0xc6, 0xe6, 0xdf, 0xc9
        );
    
    $ia5_to_unicode[0x24] = 0xa4;
    $ia5_to_unicode[0x40] = 0xa1;
    @ia5_to_unicode[0x5b .. 0x60] = (0xc4, 0xd6, 0xd1, 0xdc, 0xa7, 0xbf);
    @ia5_to_unicode[0x7b .. 0x7f] = (0xe4, 0xf6, 0xf1, 0xfc, 0xe0);
    
    my %unicode_to_ia5 = map { $ia5_to_unicode[$_] => $_ } (0 .. 127);

    if (grep { !exists($unicode_to_ia5{ord($_)}) } split(//, $message)) {
        $_[0]->{_error} .= "'$message', cannot be expressed in IA5\n";
        return 0;
    } else {
        return 1;
    }
}



sub send {
      my ($class, %values) = @_;
            
      my $to = $values{'to'} || $_[0]->{_to} || '';
      $_[0]->{_to} = $to;
      
    unless ($_[0]->{_smsmessage} && $_[0]->{_to}) {return 0;}

        my %p = (
            strMethod => 'sendSMS',
            strShortcode => '60022',        # XXX
            strMobile => $_[0]->{_to},
            intTransactionID => '999',
            intPremium => '0',     # XXX
            strMessage => $_[0]->{_smsmessage},
        );
        
        my $result = $class->do_post_request("outgoing SMS alert", \%p);
    return 1;
}


sub do_post_request {
    my ($class, $what, $params) = @_;
    our $ua;
    $ua ||= new LWP::UserAgent(
                    agent => "PledgeBank pbsmsd $rcsid",
                );

    my $t1 = time();
    eval {
        local $SIG{ALRM} = sub { die "timed out in eval\n"; };
        alarm(300);
        print_log('debug', "$what: doing POST to $_[0]->{_sms_url}");
        my $resp = $ua->post($_[0]->{_sms_url}, $params);
        alarm(0);
        if (!defined($resp)) {
            $! ||= '(no error)';
            print_log('warning', "$what: no response from user-agent; system error: $!");
            $_[0]->{_request_error} = ['systemerror', $!];
        } elsif ($resp->code() != 200) {
            print_log('warning', "$what: failure to send; HTTP status: " . $resp->status_line() . "; URL: " . $_[0]->{_sms_url});
            foreach (split(/\r?\n/, $resp->content())) {
                print_log('warning', "$what: remote error: $_");
            }
            $_[0]->{_request_error} = ['httperror', $resp->status_line()];
        } else {
            print_log('debug', "$what: did POST; " . length($resp->content()) . " bytes returned");
            $_[0]->{_request_content} = $resp->content();
        }
    };
    if ($@) {
        $@ =~ s#\n##gs;
        print_log('warning', "$what: $@");
        $_[0]->{_request_error} = ['systemerror', $@];
    }

    my $t2 = time();
    print_log('warning', "$what: HTTP POST request took " . ($t2 - $t1) . " seconds")
        if ($t2 > $t1 + 10);

    return $_[0]->{_request_error};
}


sub error {return $_[0]->{_error};}
sub request_error {return $_[0]->{_request_error};}
sub request_content {return $_[0]->{_request_content};}

sub to {
    my ($class, $to) = @_;
    if ($to) {
        $_[0]->{_to} = $to;
        $_[0]->{_to} =~ s/^\+//;
    }
    return $_[0]->{_to};
}

sub message {
    my ($class, $smsmessage) = @_;
    if ($smsmessage) {
        if ($class->check_ia5($smsmessage)) {
            $smsmessage =~ s/([^@\$ !"#%'()*+,-.\/0-9:;=?A-Z_])/sprintf('&#x%04x;', ord($1))/gei;
            $_[0]->{_smsmessage} = $smsmessage;
        }
    }
    return $_[0]->{_smsmessage};
}

1;