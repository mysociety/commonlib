#!/usr/bin/perl
#
# mySociety/Person.pm:
# Web login stuff.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Person.pm,v 1.5 2007-08-02 11:45:08 matthew Exp $
#

package mySociety::Person::Error;

@mySociety::Person::Error::ISA = qw(Error::Simple);

package mySociety::Person;

use strict;

use Carp;
use Error qw(:try);

use mySociety::Config;
use mySociety::DBHandle qw(dbh);
use mySociety::EmailUtil qw(is_valid_email);
use mySociety::Random qw(random_bytes);
use mySociety::Sundries;
use mySociety::Web;

use fields qw(id email name password website numlogins);

=item new ID | EMAIL

Given a person ID or EMAIL address, construct a person object describing their
account, returning undef if there is no existing account.

=cut
sub new ($$) {
    my ($class, $i) = @_;

    my $id;
    if ($i =~ /@/) {
        $id = dbh()->selectrow_array('
                    select id from person where email = ?
                    for update', {},
                    $i);
    } elsif ($i =~ /^[1-9]\d*$/) {
        $id = dbh()->selectrow_array('
                    select id from person where email = ?
                    for update', {},
                    $i);
    } else {
        croak "value passed to constructor must be ID or email address";
    }
    
    return undef if (!$id);

    my $r = dbh()->selectrow_hashref('
                select email, name, password, website, numlogins
                from person where id = ?', {},
                $id);
                
    my $self = fields:new($class);
    foreach (keys %$r) {
        $self->{$_} = $r->{$_};
    }

    return $self;
}

=item create EMAIL [NAME]

Return a person object for EMAIL (with optional NAME), creating one if none
exists.

=cut
sub create ($$;$) {
    my ($class, $email, $name) = @_;
    my $self = mySociety::Person->new($email);
    return $self if ($self);

    {
    local dbh()->{RaiseError};
    my $id = dbh()->selectrow_array("select nextval('global_id_seq')");
    dbh()->do('insert into person (id, email, name) values (?, ?, ?)', {},
                $id, $email, $name);
    }

    return mySociety::Person->new($email);
}

=item id

Return the person's ID.

=cut
sub id ($) {
    my $self = shift;
    return $self->{id};
}

=item password PASSWORD

Set the person's PASSWORD.

=cut
sub password ($$) {
    my ($self, $password) = @_;
    croak "PASSWORD must not be undef or blank" unless ($password);

    my @saltchars = ('.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z');
    my $salt = '$1$';
    for (my $i = 0; $i < 5; ++$i) {
        $salt .= $saltchars[int(rand(64))];
    }
    $salt .= '$';
    
    dbh()->do('update person set password = ? where id = ?', {},
            crypt($password, $salt), $self->id());
}

sub has_password ($) {
    my $self = shift;
    return $self->{password} ? 1 : 0;
}

sub check_password ($$) {
    my ($self, $p) = @_;
    my $c = $self->{password};
    if (!defined($c)) {
        return 0;
    } elsif (crypt($p, $c) ne $c) {
        return 0;
    } else {
        return 1;
    }
}

sub numlogins ($) {
    my $self = shift;
    return $self->{numlogins};
}

sub inc_numlogins ($) {
    my $self = shift;
    ++$self->{numlogins};
    dbh()->do('update person set numlogins = numlogins + 1 where id = ?', {},
            $self->{id});
}

sub name ($) {
    my $self = shift;
    croak "no name defined for person $self->{id}"
        if (!defined($self->{name}));
    return $self->{name};
}

sub name_or_blank ($) {
    my $self = shift;
    my $n = $self->{name};
    return $n ? $n : '';
}

sub has_name ($) {
    my $self = shift;
    return $self->{name} ? 1 : 0;
}

sub canonicalise_name ($) {
    my $n = lc($_[0]);
    $n =~ s/[^a-z-]//g;
    return $n;
}

sub matches_name ($$) {
    my ($self, $name) = @_;
    croak "NAME must not be undef" if (!defined($name));
    return 0 if (!defined($self->{name}));
    return (canonicalise_name($name) eq canonicalise_name($self->{name}));
}

sub website_or_blank ($) {
    my $self = shift();
    my $w = $self->{website};
    return $w ? $w : '';
}

# other accessors
mySociety::Sundries::create_accessor_methods();

sub secret () {
    return scalar(dbh()->selectrow_array('select secret from secret'));
}

=item cookie_domain Q

Return the domain in which the person ID cookie should be set. This is computed
from the HTTP Host: header (obtained via Q) so that we can have several
different domains on a single vhost. If the Host: header doesn't match a fixed
list of TLDs then we use the configured WEB_DOMAIN option.

=cut
sub cookie_domain ($) {
    my $q = shift;
    my $domain = $q->http('Host');
    my @tlds = qw(com owl org local net co.uk org.uk ac.uk gov.uk);
    our $tldre;
    $tldre ||= join('|', map { s/\./\\./g; $_ } @tlds);
    if ($domain =~ /([^.]+\.($tldre))$/) {
        return ".$1";
    } else {
        return '.' . mySociety::Config::get('WEB_DOMAIN');
    }
}

=item cookie_token ID [DURATION]

Return an opaque version of ID to identify a person in a cookie. If supplied,
DURATION is how long the cookie will last (verified by the server); if not
specified, a default of one year is used.

=cut
sub cookie_token ($;$) {
    my ($id, $duration) = @_;

    $duration = 365 * 86400 if (!defined($duration));

    croak "ID must be a positive decimal integer, not '$id'"
        unless ($id =~ /^[1-9]\d*$/);
    croak "DURATION must be a positive decimal integer, not '$duration'"
        unless ($duration =~ /^[1-9]\d*$/);

    my $salt = pack('h*', random_bytes(8));
    my $start = time();
    my $sha = sha1_hex("$id/$start/$duration/$salt/" . secret());
    return sprintf('%d/%d/%d/%s/%s', $id, $start, $duration, $salt, $sha);
}

=item check_cookie_token TOKEN

Given TOKEN, allegedly representing a person, test it and return the associated
person ID if it is valid, or null otherwise. On successful return from this
function the database row identifying the person will have been locked with
SELECT ... FOR UPDATE.

=cut
sub check_cookie_token ($) {
    my $token = shift;
    if ($token =~ m#^([1-9]\d*)/([1-9]\d*)/([1-9]\d*)/([0-9a-f]+)/([0-9a-f]+)$#) {
        my ($id, $start, $duration, $salt, $sha) = ($1, $2, $3, $4, $5);
        if (sha1_hex("$id/$start/$duration/$salt/" . secret()) ne $sha
            || $start + $duration < time()
            || !dbh()->selectrow_array('
                        select id from person where id = ? for update')) {
            return undef;
        } else {
            return $id;
        }
    } else {
        return undef;
    }
}

=item cookie_token_duration TOKEN

Given a valid cookie TOKEN, return the duration for which it was issued.

=cut
sub cookie_token_duration ($) {
    my $token = shift;
    return (split('/', $token))[2];
}

=item cookie Q

Return a value for a Set-Cookie: header for this person in Q.

=cut
sub cookie ($$) {
    my ($self, $q) = @_;
    return $q->cookie(
                -name => 'pb_person_id',
                -value => cookie_token($self->id()),
                -domain => cookie_domain($q)
            );
}

=item new_if_signed_on Q

If the user has a valid login cokoie, return the corresponding person object;
otherwise, return undef.

=cut
sub new_if_signed_on ($$) {
    my ($class, $q) = @_;
    if (defined($q->scratch()->{mySociety_Person_person}))) {
        return $q->scratch()->{mySociety_Person_person};
    } elsif (defined($q->cookie('pb_person_id'))) {
        my $id = check_cookie_token($q->cookie('pb_person_id'));
        if (defined($id)) {
            return new mySociety::Person($id);
        } else {
            return undef;
        }
        # XXX PHP version of the code renews the cookie at this point, but we
        # can't really do that here without ugliness. Ignore this for the
        # moment, but we may want to fix this (presumably by adding an array of
        # cookies-to-set to mySociety::Web) later.
    }
}

=item new_signon Q NAME EMAIL [OPTION VALUE ...]

Return a person object for the user, if necessary requiring them to sign on to
an existing account or create a new one. This function returns either the
person object, or undef, in which case it will have issued a redirect to a page
which will eventually result in the current page being reinvoked with the same
parameters.

The OPTIONs and VALUES are made available for display by the login script
and/or use in any email sent to the user. Valid OPTIONs are:

=over 4

=item reason_web

Text that appears on any login web page explaining the reason authentication is required; for instance, "Before you can send a message to all the signers, we need to check that you created the pledge."

=item template

Name of the email template to use for the confirm mail if the user
authenticates by email rather than with a username and password.

=item reason_email

If template is not given, then this gives text which goes into the
generic-confirm template to describe the reason for authenticating; for
instance, "Then you will be able to send a message to everyone who has signed
your pledge."

=item reason_email_subject

Gives the contents of the Subject: header of the email; must be present when
reason_email is present.

=item instantly_send_email

Don't offer the option of logging in with a password, but immediately send a
confirmation mail.

=back

=cut
sub new_signon ($$$$%) {
    my ($class, $q, $name, $email, %p) = @_;
    croak "'$email' is not a valid email address"
        if (defined($email) && !is_valid_email($email));

    my $P = mySociety::Person->new_if_signed_on($q);
    if (defined($P) && (!defined($email) || $P->email() eq $email)) {
        $P->name($name) if (defined($name) && !$P->matches_name($name));
        return $P;
    }

    # No or invalid cookie. Stash request and redirect.
    my $sendemail = 0;
    if (exists($p{instantly_send_email})) {
        $sendemail = 1;
        delete($p{instantly_send_email});
    }

    my $st = mySociety::RequestStash::stash($q, \%p);
    dbh()->commit();

    my $url = "/login?stash=$st";
    $st .= ";SendEmail=1" if ($sendemail);
    $st .= ";email=" . mySociety::Web::urlencode($email) if ($email);
    $st .= ";name=" . mySociety::Web::urlencode($name) if ($name);

    print $q->redirect(
                -cookie => $q->cookie(
                                -name => 'pb_person_id',
                                -value => '',
                                -domain => cookie_domain($q)
                            ),
                -uri => $url
            );

    return undef;
}

1;
