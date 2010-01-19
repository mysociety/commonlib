#!/usr/bin/perl
#
# mySociety/EmailUtil.pm:
# Utilities for email, split from mySociety::Util.
#

package mySociety::EmailUtil;

use strict;

use Net::SMTP;

use mySociety::Config;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw(&is_valid_email &send_email);
}
our @EXPORT_OK;

=head1 NAME

mySociety::EmailUtil

=head1 DESCRIPTION

Utilities for email, split from mySociety::Util.

=head1 FUNCTIONS

=over 4



=item is_valid_email ADDRESS

Restricted syntax-check for ADDRESS. We check for what RFC2821 calls a
"mailbox", which is "local-part@domain", with the restriction of no
address-literal domains (e.g "[127.0.0.1]"). We also don't do bang paths.

=cut
sub is_valid_email ($) {
    my $addr = shift;
    our $is_valid_address_re;

    # This is derived from the grammar in RFC2822.
    if (!defined($is_valid_address_re)) {
        # mailbox = local-part "@" domain
        # local-part = dot-string | quoted-string
        # dot-string = atom ("." atom)*
        # atom = atext+
        # atext = any character other than space, specials or controls
        # quoted-string = '"' (qtext|quoted-pair)* '"'
        # qtext = any character other than '"', '\', or CR
        # quoted-pair = "\" any character
        # domain = sub-domain ("." sub-domain)* | address-literal
        # sub-domain = [A-Za-z0-9][A-Za-z0-9-]*
        # XXX ignore address-literal because nobody uses those...

        my $specials = '()<>@,;:\\\\".\\[\\]';
        my $controls = '\\000-\\037\\177';
        my $highbit = '\\200-\\377';
        my $atext = "[^$specials $controls$highbit]";
        my $atom = "$atext+";
        my $dot_string = "$atom(\\s*\\.\\s*$atom)*";
        my $qtext = "[^\"\\\\\\r\\n$highbit]";
        my $quoted_pair = '\\.';
        my $quoted_string = "\"($qtext|$quoted_pair)*\"";
        my $local_part = "($dot_string|$quoted_string)";
        my $sub_domain = '[A-Za-z0-9][A-Za-z0-9-]*';
        my $domain = "$sub_domain(\\s*\\.\\s*$sub_domain)*";

        $is_valid_address_re = "^$local_part\\s*@\\s*$domain\$";
    }
    
    if ($addr =~ m#$is_valid_address_re#) {
        return 1;
    } else {
        return 0;
    }
}


use constant EMAIL_SUCCESS => 0;
use constant EMAIL_SOFT_ERROR => 1;
use constant EMAIL_HARD_ERROR => 2;

# send_email_sendmail TEXT SENDER RECIPIENT ...
# Implementation of send_email which calls out to /usr/sbin/sendmail.
sub send_email_sendmail ($$@) {
    my ($text, $sender, @recips) = @_;
    my $pid;
    my $ret;
#    local $SIG{PIPE} = 'IGNORE';
    defined($pid = open(SENDMAIL, '|-')) or die "fork: $!\n";
    if (0 == $pid) {
        # Close all filehandles other than standard ones. This will prevent
        # perl from messing up database connections etc. on exit.
        use POSIX;
        my $openmax = POSIX::_SC_OPEN_MAX();
        for (my $fd = 3; $fd < POSIX::sysconf($openmax); ++$fd) {
            POSIX::close($fd);
        }
        # Child.
        # XXX should close all other fds
        exec('/usr/sbin/sendmail',
                '-i',
                '-f', $sender,
                @recips);
        exit(255);
    }

    print SENDMAIL $text or die "write: $!\n";
    close SENDMAIL;

    if ($? & 127) {
        # Killed by signal; assume that message was not queued.
        $ret = EMAIL_HARD_ERROR;
    } else {
        # We need to distinguish between success (anything which means that
        # the message will later be delivered or bounced), soft failures
        # (for which redelivery should be attempted later) and hard
        # failures (which mean that delivery will not succeed even if
        # retried).
        #
        # From sendmail(8):
        #
        # Sendmail returns an exit status describing what it did.  The
        # codes are defined in <sysexits.h>:
        #
        #   EX_OK           Successful completion on all addresses.
        #   EX_NOUSER       User name not recognized.
        #   EX_UNAVAILABLE  Catchall meaning necessary resources were not
        #                   available.
        #   EX_SYNTAX       Syntax error in address.
        #   EX_SOFTWARE     Internal software error, including bad
        #                   arguments.
        #   EX_OSERR        Temporary operating system error, such as
        #                   "cannot fork."
        #   EX_NOHOST       Host name not recognized.
        #   EX_TEMPFAIL     Message could not be sent immediately, but was
        #                   queued.
        #
        # BUT Exim only returns EXIT_SUCCESS (0) or EXIT_FAILURE (1), and does
        # not distinguish permanent from temporary failure. Which means that
        # this isn't a lot of good.
        my $ex = ($? >> 8);

        my %return_codes = (
                0       => EMAIL_SUCCESS,       # EX_OK
                75      => EMAIL_SUCCESS,       # EX_TEMPFAIL

                69      => EMAIL_SOFT_ERROR,    # EX_UNAVAILABLE
                71      => EMAIL_SOFT_ERROR     # EX_OSERR

                # all others: assume hard failure.
            );
        
        if (exists($return_codes{$ex})) {
            $ret = $return_codes{$ex};
        } else {
            $ret = EMAIL_HARD_ERROR;
        }
    }
    close(SENDMAIL);

    return $ret;

}

# send_email_smtp SMARTHOST TEXT SENDER RECIPIENT ...
# Implementation of send_email which calls out to an SMTP server.
sub send_email_smtp ($$$@) {
    my ($smarthost, $text, $sender, @recips) = @_;
    my $smtp = new Net::SMTP($smarthost, Timeout => 15);
    return EMAIL_SOFT_ERROR if (!$smtp);

    # Actually this could be a hard error, but since that could only really be
    # the result of a misconfiguration, treat it as a soft error and give the
    # admins a chance to fix the problem.
    return EMAIL_SOFT_ERROR
        unless ($smtp->mail($sender));

    foreach my $addr (@recips) {
        if (!$smtp->to($addr)) {
            # 5xx means "known to be undeliverable".
            my $c = $smtp->code();
            return (defined($c) && $c =~ /^5..$/)
                    ? EMAIL_HARD_ERROR
                    : EMAIL_SOFT_ERROR;
        }
    }

    my @ll = map { "$_\r\n" } split(/\n/, $text);
    return EMAIL_SOFT_ERROR
        unless ($smtp->data(\@ll));

    $smtp->quit();
    undef $smtp;
    return EMAIL_SUCCESS;
}

=item send_email TEXT SENDER RECIPIENT ...

Send an email. TEXT is the full, already-formatted, with-headers, on-the-wire
form of the email (except that line-endings should be "\n" not "\r\n"). SENDER
is the B<envelope> sender of the mail (B<not> the From: address, which you
should specify yourself). RECIPIENTs are the B<envelope> recipients of the
mail. Returns one of the constants EMAIL_SUCCESS, EMAIL_SOFT_FAILURE, or
EMAIL_HARD_FAILURE depending on whether the email was successfully sent (or
queued), a temporary ("soft") error occurred, or a permanent ("hard") error
occurred.

=cut
sub send_email ($$@) {
    my ($text, $sender, @recips) = @_;
    my $smarthost = mySociety::Config::get('SMTP_SMARTHOST', undef);
    if ($smarthost) {
        return send_email_smtp($smarthost, $text, $sender, @recips);
    } else {
        warn "No OPTION_SMTP_SMARTHOST defined; calling sendmail binary instead";
        return send_email_sendmail($text, $sender, @recips);
    }
}

1;
