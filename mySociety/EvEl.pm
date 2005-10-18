#!/usr/bin/perl
#
# mySociety/EvEl.pm:
# Client interface to EvEl (via RABX).
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: EvEl.pm,v 1.1 2005-10-18 16:46:57 chris Exp $
#

package EvEl;

use strict;

use RABX;
use mySociety::Config;

=head1 NAME

mySociety::EvEl

=head1 DESCRIPTION

RABX client interface for EvEl, the generic email tools.

=head1 FUNCTIONS

=over 4

=item configure [URL]

Set the URL which will be used to call the functions over RABX. If you don't
specify the URL, mySociety configuration variable EVEL_URL will be used instead.

=cut
my $rabx_client = undef;
sub configure (;$) {
    my ($url) = @_;
    $url = mySociety::Config::get('EVEL_URL') if !defined($url);
    $rabx_client = new RABX::Client($url) or die qq(Bad RABX URL "$url");
}

=back

=head2 Formatting mails

=over 4

=item construct_email SPEC

Construct a wire-format (RFC2822) email message according to SPEC, which is an
associative array containing elements as follows:

=over 4

=item _body_

Text of the message to send, as a UTF-8 string with "\n" line-endings.

=item _unwrapped_body_

Text of the message to send, as a UTF-8 string with "\n" line-endings. It will
be word-wrapped before sending.

=item _template_, _parameters_

Templated body text and an associative array of template parameters. _template
contains optional substititutions <?=$values['name']?>, each of which is
replaced by the value of the corresponding named value in _parameters_. It is
an error to use a substitution when the corresponding parameter is not present
or undefined. The first line of the template will be interpreted as contents of
the Subject: header of the mail if it begins with the literal string 'Subject:
' followed by a blank line. The templated text will be word-wrapped to produce
lines of appropriate length.

=item To

Contents of the To: header, as a literal UTF-8 string or an array of addresses
or [address, name] pairs.

=item From

Contents of the From: header, as an email address or an [address, name] pair.

=item Cc

Contents of the Cc: header, as for To.

=item Subject

Contents of the Subject: header, as a UTF-8 string.

=item Message-ID

Contents of the Message-ID: header, as a US-ASCII string.

=item I<any other element>

interpreted as the literal value of a header with the same name.

=back

If no Message-ID is given, one is generated. If no To is given, then the string
"Undisclosed-Recipients: ;" is used. If no From is given, a generic no-reply
address is used. It is an error to fail to give a body, unwrapped body or a
templated body; or a Subject.

=cut
sub construct_email ($) {
    my ($spec) = (@_);
    configure() if (!defined($rabx_client));
    return $rabx_client->call('EvEl.construct_email', $spec);
}

=back

=head2 Individual mails

=over 4

=item send MESSAGE RECIPIENTS

Send a MESSAGE to the given RECIPIENTS.  MESSAGE is either the full text of a
message (in its RFC2822, on-the-wire format) or an associative array as passed
to construct_email.  RECIPIENTS is either one email address string, or an 
array of them for multiple recipients.

=cut
sub send ($$) {
    my ($msg, $recips) = @_;
    configure() if (!defined($rabx_client));
    return $rabx_client->call('EvEl.send', $msg, $recips);
}

=item is_address_bouncing ADDRESS

Return true if we have received bounces for the ADDRESS.

=cut
sub is_address_bounding ($) {
    my ($addr) = @_;
    configure() if (!defined($rabx_client));
    return $rabx_client->call('EvEl.is_address_bouncing', $addr);
}

# XXX mailing lists

=back

=cut

1;
