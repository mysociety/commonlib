#!/usr/bin/perl
#
# mySociety/Email.pm:
# Email utilities.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Email.pm,v 1.1 2006-07-31 09:57:41 chris Exp $
#

package mySociety::Email::Error;

use Error qw(:try);

@mySociety::Email::Error::ISA = qw(Error::Simple);

package mySociety::Email;

use strict;

use Error qw(:try);
use MIME::Entity;
use MIME::Words;
use Text::Wrap qw();

=item format_mimewords STRING

Return STRING, formatted for inclusion in an email header.

=cut
sub format_mimewords ($) {
    my ($text) = @_;
    # This is unpleasant. Whitespace which separates two encoded-words is not
    # significant, so we need to fold it in to one of them. Rather than having
    # some complicated state-machine driven by words, just encode the whole
    # line if it contains any non-ASCII characters. However, this is going to
    # suck whatever happens, because we can't include a blank in a
    # quoted-printable MIME-word, so we have to encode it as =20 or whatever,
    # so this is still going to be near-unreadable for users whose MUAs suck
    # at MIME.
    utf8::encode($text); # turn to string of bytes
    if ($text =~ m#[\x00-\x1f\x80-\xff]#) {
        $text =~ s#(\s|[\x00-\x1f\x80-\xff])#sprintf('=%02x', ord($1))#ge;
        $text = "=?UTF-8?Q?$text?="
    }
    utf8::decode($text);
    return $text;
}

=item format_email_address NAME ADDRESS

Return a suitably MIME-encoded version of "NAME <ADDRESS>" suitable for use in
an email From:/To: header.

=cut
sub format_email_address ($$) {
    my ($name, $addr) = @_;
    $name = format_mimewords($name);
    $name =~ s/"/\\"/g;
    $name =~ s/\\/\\\\/g;
    $name = "\"$name\"";
    return sprintf('%s <%s>', $name, $addr);
}

# do_one_substitution PARAMS NAME
# If NAME is not present in PARAMS, throw an error; otherwise return the value
# of the relevant parameter.
sub do_one_substitution ($$) {
    my ($p, $n) = @_;
    throw mySociety::Email::Error("Substitution parameter '$n' is not present")
        unless (exists($p->{$n}));
    throw mySociety::Email::Error("Substitution parameter '$n' is not undefined")
        unless (defined($p->{$n}));
    return $p->{$n};
}

=item do_template_substitution TEMPLATE PARAMETERS

Given the text of a TEMPLATE and a reference to a hash of PARAMETERS, return
in list context the subject and body of the email.

=cut
sub do_template_substitution ($$) {
    my ($body, $params) = @_;
    $body =~ s#<\?=\$values\['([^']+)'\]\?>#do_one_substitution($params, $1)#ges;

    my $subject;
    if ($body =~ m#^Subject: ([^\n]*)\n\n#s) {
        $subject = $1;
        $body =~ s#^Subject: ([^\n]*)\n\n##s;
    }

    # Merge paragraphs into their own line.  Two blank lines separates a
    # paragraph.
    $body =~ s#(^|[^\n])[ \t]*\n[ \t]*($|[^\n])#$1 $2#g;

    # Wrap text to 72-column lines.
    local($Text::Wrap::columns = 69);
    local($Text::Wrap::huge = 'overflow');
    my $wrapped = Text::Wrap::wrap('     ', '     ', $body);
    $wrapped =~ s/^\s+$//mg;

    return ($subject, $wrapped);
}


1;
