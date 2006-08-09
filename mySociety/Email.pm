#!/usr/bin/perl
#
# mySociety/Email.pm:
# Email utilities.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Email.pm,v 1.3 2006-08-09 11:29:21 chris Exp $
#

package mySociety::Email::Error;

use Error qw(:try);

@mySociety::Email::Error::ISA = qw(Error::Simple);

package mySociety::Email;

use strict;

use Error qw(:try);
use MIME::Entity;
use MIME::Words;
use POSIX qw();
use Text::Wrap qw();

use mySociety::Util qw(random_bytes);

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

=item construct_email SPEC

Construct an email message according to SPEC, which is an associative array
containing elements as given below. Returns an on-the-wire email (though with
"\n" line-endings).

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

=item I<any other element>

interpreted as the literal value of a header with the same name.

=back

If no Date is given, the current date is used. If no To is given, then the
string "Undisclosed-Recipients: ;" is used. It is an error to fail to give a
body, unwrapped body or a templated body; or From or Subject.

=cut
sub construct_email ($) {
    my $p = shift;

    if (!exists($p->{_body_}) && !exists($p->{_unwrapped_body_})
        && (!exists($p->{_template_}) || !exists($p->{_parameters_}))) {
        throw mySociety::Email::Error("Must specify field '_body_' or '_unwrapped_body_', or both '_template_' and '_parameters_'");
    }

    if (exists($p->{_unwrapped_body_})) {
        throw mySociety::Email::Error("Fields '_body_' and '_unwrapped_body_' both specified") if (exists($p->{_body_}));
        local($Text::Wrap::columns = 69);
        local($Text::Wrap::huge = 'overflow');
        $p->{_body_} = Text::Wrap::wrap('     ', '     ', $p->{_unwrapped_body_});
        $p->{_body_} =~ s/^\s+$//mg;
        delete($p->{_unwrapped_body_});
    }

    if (exists($p->{_template_})) {
        throw mySociety::Email::Error("Template parameters '_parameters_' must be an associative array")
            if (ref($p->{_parameters_}) ne 'HASH');
        
        (my $subject, $p->{_body_}) = mySociety::Email::do_template_substitution($p->{_template_}, $p->{_parameters_});
        delete($p->{_template_});
        delete($p->{_parameters_});

        $p->{Subject} = $subject if (defined($subject));
    }

    throw mySociety::Email::Error("missing field 'Subject' in MESSAGE") if (!exists($p->{Subject}));
    throw mySociety::Email::Error("missing field 'From' in MESSAGE") if (!exists($p->{From}));

    my %hdr;
    $hdr{Subject} = mySociety::Email::format_mimewords($p->{Subject});

    # To: and Cc: are address-lists.
    foreach (qw(To Cc)) {
        next unless (exists($p->{$_}));

        if (ref($p->{$_}) eq '') {
            # Interpret as a literal string in UTF-8, so all we need to do is
            # escape it.
            $hdr{$_} = mySociety::Email::format_mimewords($p->{$_});
        } elsif (ref($p->{$_}) eq 'ARRAY') {
            # Array of addresses or [address, name] pairs.
            my @a = ( );
            foreach (@{$p->{$_}}) {
                if (ref($_) eq '') {
                    push(@a, $_);
                } elsif (ref($_) ne 'ARRAY' || @$_ != 2) {
                    throw mySociety::Email::Error("Element of '$_' field should be string or 2-element array");
                } else {
                    push(@a, mySociety::Email::format_email_address($_->[1], $_->[0]));
                }
            }
            $hdr{$_} = join(', ', @a);
        } else {
            throw mySociety::Email::Error("Field '$_' in MESSAGE should be single value or an array");
        }
    }

    if (exists($p->{From})) {
        if (ref($p->{From}) eq '') {
            $hdr{From} = $p->{From}; # XXX check syntax?
        } elsif (ref($p->{From}) ne 'ARRAY' || @{$p->{From}} != 2) {
            throw mySociety::Email::Error("'From' field should be string or 2-element array");
        } else {
            $hdr{From} = mySociety::Email::format_email_address($p->{From}->[1], $p->{From}->[0]);
        }
    }

    # Some defaults
    $hdr{To} ||= 'Undisclosed-recipients: ;';
    $hdr{From} ||= sprintf('%sno-reply@%s',
                            mySociety::Config::get('EVEL_VERP_PREFIX'),
                            mySociety::Config::get('EVEL_VERP_DOMAIN')
                        );
    $hdr{'Message-ID'} ||= sprintf('<%s%s@%s>',
                            mySociety::Config::get('EVEL_VERP_PREFIX'),
                            unpack('h*', random_bytes(5)),
                            mySociety::Config::get('EVEL_VERP_DOMAIN')
                        );
    $hdr{Date} ||= POSIX::strftime("%a, %d %h %Y %T %z", localtime(time()));

    foreach (keys(%$p)) {
        $hdr{$_} = $p->{$_} if ($_ ne '_data_' && !exists($hdr{$_}));
    }

    # MIME::Entity->build() apparently expects *byte strings* as its data
    # argument; otherwise some crazy conversion goes on and it emits encoded
    # ISO-8859-1 data, rather than UTF-8.
    utf8::encode($p->{_body_});
    return MIME::Entity->build(
                    %hdr,
                    Data => $p->{_body_},
                    Type => 'text/plain; charset="utf-8"',
                    Encoding => 'quoted-printable'
                )->stringify();
}


1;
