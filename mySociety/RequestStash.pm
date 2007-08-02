#!/usr/bin/perl
#
# mySociety/RequestStash.pm:
# Save and restore details of requests.
#
# Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: RequestStash.pm,v 1.3 2007-08-02 11:45:08 matthew Exp $
#

package mySociety::RequestStash::Error;

@mySociety::RequestStash::Error::ISA = qw(Error::Simple);

package mySociety::RequestStash;

use strict;

use Carp;
use Error qw(:try);
use IO::String;

use RABX;

use mySociety::DBHandle qw(dbh);
use mySociety::Random qw(random_bytes);
use mySociety::Web qw(ent urlencode);

=item stash Q [EXTRA]

=item stash METHOD URL PARAMS EXTRA

=cut
sub stash ($;$$$) {
    if (@_ == 1 || @_ == 2) {
        # Reconstruct from CGI object
        my ($q, $extra) = @_;

        my $p = { };
        foreach my $key ($q->param()) {
            my @val = $q->param($key);
            if (@val > 1) {
                $p->{$key} = [@val];
            } else {
                $p->{$key} = $val[0];
            }
        }

        return stash($q->request_method(), $q->url(), $p, $extra);
    }
    
    # Specified explicitly.
    my ($method, $url, $params, $extra) = @_;

    my $key = unpack('h*', random_bytes(8));
    
    if ($method eq 'GET' || $method eq 'HEAD') {
        # Strip query from URL and recreate it.
        $url =~ s/\?.*$//;
        my @a = ();
        foreach my $k (keys(%$params)) {
            my $v = $params->{$k};
            $v = [$v] if (!ref($v));
            push(@a, map { urlencode($k) . '=' . urlencode($_) } @$v);
        }
        $url .= "?" . join('&', @a) if (@a);    # XXX prefer ';' ?
    
        dbh()->do('
                insert into requeststash (key, method, url, extra)
                values (?, ?, ?, ?)', {},
                $key, 'GET', $url, $extra);
    } elsif ($method eq 'POST') {
        my $ser = '';
        my $h = new IO::String($ser);
        RABX::wire_wr($params, $h);
        my $st = dbh()->prepare("
                insert into requeststash (key, method, url, post_data, extra)
                values (?, 'POST', ?, ?, ?)");
        $st->bind_param(1, $key);
        $st->bind_param(2, $url);
        $st->bind_param(3, $ser, { pg_type => DBD::Pg::PG_BYTEA });
        $st->bind_param(4, $extra);
        $st->execute();
    } else {
        croak "cannot stash request with method $method";
    }

    # XXX this probably shouldn't be here
    my $t = dbh()->selectrow_array("
            select ms_current_timestamp() - '365 days'::interval");
    dbh()->do('delete from requeststash where whensaved < ?', {}, $t);

    return $key;
}

=item redirect Q KEY [COOKIE]

=cut
sub redirect ($$;$) {
    my ($q, $key, $cookie) = @_;
    my ($method, $url, $post_data) = dbh()->selectrow_array('
            select method, url, post_data from requeststash where key = ?', {},
            $key);
    if (!defined($method)) {
        throw mySociety::RequestStash::Error("If you got the email more than a year ago, then your request has probably expired.  Please try doing what you were doing from the beginning.");
    } elsif ($method eq 'GET') {
        print $q->redirect(-uri => $url, -cookie => $cookie);
    } else {
        # POST. Evil.
        my $h = new IO::String($post_data);
        my $p = RABX::wire_rd($h);
        my $name;
        for (my $i = 0; ; ++$i) {
            $name = "f$i";
            last unless (exists($p->{$name}));
        }
        my $html = <<EOF
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
<html>
    <head>
        <title>Redirect...</title>
        <meta http-equiv="Content-Script-Type" content="text/javascript">
    </head>
    <body onload="document.$name.submit()">
        <form name="$name" method="POST" action="@{[ ent($url) ]}">
EOF
       
        foreach my $k (keys %$p) {
            my $v = $p->{$k};
            $v = [$v] if (!ref($v));
            foreach (@$v) {
                $html .= <<EOF;
            <input type="hidden" name="@{[ ent($k) ]}" value="@{[ ent($_) ]}">
EOF
            }
        }
        $html .= <<EOF;
            <input type="submit" value="Click here to continue">
        </form>
    </body>
</html>
EOF
        print $q->header(
                    -content_length => length($html),
                    -cookie => $cookie
                ), $html;
    }
}

=item get_extra KEY

=cut
sub get_extra ($) {
    return scalar(dbh()->selectrow_array('
                select extra from requeststash where key = ?', {}, $_[0]));
}

=item delete KEY

=cut
sub delete ($) {
    dbh()->do('delete from stash where key = ?', {}, $_[0]);
}

1;
