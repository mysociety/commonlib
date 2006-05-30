#!/usr/bin/perl
#
# RABX.pm:
# RPC using Anything But XML.
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: RABX.pm,v 1.18 2006-05-30 11:16:04 chris Exp $

# References:
#   Netstrings are documented here: http://cr.yp.to/proto/netstrings.txt

package RABX::Error;

use Error qw(:try);

@RABX::Error::ISA = qw(Error);

# Error codes: 0--1023 are reserved for errors in the RABX layer. Everything
# else is available for users.
my %code = (
        Unknown     => 0,       # Unknown/undetected error
        Interface   => 1,       # Misuse of API interface
        Transport   => 2,       # Physical error in transport layer
        Protocol    => 3,       # Malformed data or other protocol error

        User        => 1024     # ... and above
    );

my %code_to_name = reverse(%code);

use constant UNKNOWN   => 0;
use constant INTERFACE => 1;
use constant TRANSPORT => 2;
use constant PROTOCOL  => 3;
use constant USER      => 1024;

use constant SERVER     => 512; # Or'd with code to indicate, "error detected by
                                # server" -- otherwise it is assumed that the
                                # error was detected by the client.

use constant MASK       => 511; # Mask for deriving error code.

# yuk.
foreach (keys %code) {
    my $u = uc($_);
    eval <<EOF;
package RABX::Error::$_;
\@RABX::Error::${_}::ISA = qw(RABX::Error);
sub new (\$\$;\$) {
    my (\$class, \$text, \$extra) = \@_;
    return new RABX::Error(\$text, RABX::Error::$u, \$extra);
}
EOF
}

sub new ($$$;$) {
    my ($class, $text, $value, $extra) = @_;
    my $self = new Error(-text => $text, -value => [$value, $extra]);
    if ($class eq 'RABX::Error') {
        if ($value >= USER) {
            return bless($self, 'RABX::Error::User');
        } else {
            my $c = $code_to_name{$value & MASK};
            $c ||= "Unknown";
            return bless($self, "RABX::Error::$c");
        }
    } else {
        return bless($self, $class);
    }
}

sub value ($) {
    my $self = shift;
    return Error::value($self)->[0];
}

sub extradata ($) {
    my $self = shift;
    return Error::value($self)->[1];
}

sub stringify ($) {
    my $self = shift;
    return sprintf('%s', $self->text());
}

package RABX;

use strict;

use Error qw(:try);
use IO::String;
use utf8;

my $have_fast_serialisation = 0;
BEGIN {
    eval {
        require RABX::Fast;
        $have_fast_serialisation = 1;
    };
}

use constant PROTOCOL_VERSION => 0;

=head1 NAME

RABX

=head1 DESCRIPTION

"RPC over Anything But XML". A simple and fast-to-parse protocol for RPC calls
over HTTP and other transports.

=head1 FUNCTIONS

=over 4

=item netstring_wr STRING HANDLE

Return STRING, formatted as a netstring.

=cut
sub netstring_wr ($$) {
    my ($str, $h) = @_;
    # If the string has the UTF-8 flag on, then length() will count characters
    # rather than bytes.
    utf8::encode($str) if (utf8::is_utf8($str));
    $h->print(length($str), ':', $str, ',');
}

=item netstring_rd HANDLE

Attempts to parse a netstring from HANDLE.

=cut
sub netstring_rd ($) {
    my ($h) = @_;
    
    my $len = 0;
    my $c;
    
    while (defined($c = $h->getc())) {
        last if ($c eq ':');
        throw RABX::Error(qq#bad character '$c' in netstring length#, RABX::Error::PROTOCOL) if ($c !~ m#\d#);
        $len = ($len * 10) + ord($c) - ord('0');
    }

    if (!defined($c)) {
        throw RABX::Error("$! reading netstring length", RABX::Error::TRANSPORT) if ($h->error());
        throw RABX::Error("EOF reading netstring length", RABX::Error::PROTOCOL);
    }

    my $string = '';
 
    while (length($string) < $len) {
        my $n = $h->read($string, $len - length($string), length($string));
        throw RABX::Error("$! reading netstring content", RABX::Error::TRANSPORT)
            if (!defined($n));
        throw RABX::Error("EOF reading netstring content", RABX::Error::PROTOCOL)
            if ($n == 0);
    }

    if (!defined($c = $h->getc())) {
        throw RABX::Error("$! reading netstring trailer", RABX::Error::TRANSPORT) if ($h->error());
        throw RABX::Error("EOF reading netstring trailer", RABX::Error::PROTOCOL);
    }

    throw RABX::Error("bad netstring trailer character '$c'", RABX::Error::PROTOCOL)
        if ($c ne ',');

    return $string;
}

# is_really_utf8 DATA
# utf8::is_utf8 returns false for a UTF-8 string which does not contain any
# characters outside the ASCII range.
sub is_really_utf8 ($) {
    return utf8::is_utf8($_[0]) || $_[0] !~ /[^\x00-\x7f]/;
}

=item wire_wr X HANDLE

Format X (which may be a reference or a scalar) into HANDLE.

=cut
sub wire_wr ($$);
sub wire_wr ($$) {
    my $ref = ref($_[0]) ? $_[0] : \$_[0];
    my $h = $_[1];

    if (ref($ref) eq 'SCALAR') {
        # Four cases:
        #   B arbitrary binary data
        #   T string of text (UTF8)
        #   R floating-point number
        #   I integer
        #   N null
        if (!defined($$ref)) {
            $h->print('N');
            return;
        } elsif ($$ref =~ m#^-?([1-9]\d*|0)$#) {
            $h->print('I');
        } elsif ($$ref =~ m#^-?(?:0|[1-9]\d*)(?:\.\d*)(?:|e[+-]?\d+)$#) {
            $h->print('R');
        } elsif (is_really_utf8($$ref)) {
            $h->print('T');
        } else {
            $h->print('B');
        }
        netstring_wr($$ref, $h);
    } elsif (ref($ref) eq 'ARRAY') {
        # Format is L . number of elements . element . element ...
        $h->print('L');
        netstring_wr(scalar(@$ref), $h);
        foreach (@$ref) {
            wire_wr($_, $h);
        }
    } elsif (ref($ref) eq 'HASH') {
        # Format is A . number of keys . key . value . key . value ...
        $h->print('A');
        netstring_wr(scalar(keys %$ref), $h);
        foreach (keys %$ref) {
            wire_wr($_, $h);
            wire_wr($ref->{$_}, $h);
        }
    } else {
        throw RABX::Error(q#X cannot be a reference to "# . ref($ref) . q#"#, RABX::Error::INTERFACE);
    }
}

=item wire_rd HANDLE

Parse on-the-wire data from HANDLE and return its representation in perl data
structures.

=cut
sub wire_rd ($);
sub wire_rd ($) {
    my ($h) = @_;

    my $type = $h->getc();
    if (!defined($type)) {
        throw RABX::Error("$! reading type indicator character", RABX::Error::TRANSPORT) if ($h->error());
        throw RABX::Error("EOF reading type indicator character", RABX::Error::PROTOCOL);
    }

    if ($type eq 'N') {
        return undef;
    } elsif ($type =~ m#^[IRB]$#) {
        return netstring_rd($h); # XXX type checks
    } elsif ($type eq 'T') {
        my $t = netstring_rd($h);
        throw RABX::Error("data in 'T' string are not valid UTF-8 octets: '$t'")
            if (!utf8::decode($t));
        return $t;
    } elsif ($type eq 'L') {
        my $len = netstring_rd($h);
        throw RABX::Error("bad list length '$len'", RABX::Error::PROTOCOL) unless ($len =~ m#^(0|[1-9]\d*)$#);
        my @r = ( );
        for (my $i = 0; $i < $len; ++$i) {
            push(@r, wire_rd($h));
        }
        return \@r;
    } elsif ($type eq 'A') {
        my $len = netstring_rd($h);
        throw RABX::Error("bad associative array length '$len'", RABX::Error::PROTOCOL) unless ($len =~ m#^(0|[1-9]\d*)$#);
        my %r = ( );
        for (my $i = 0; $i < $len; ++$i) {
            my $k = wire_rd($h);
            throw RABX::Error("repeated element '$k' in associative array", RABX::Error::PROTOCOL) if (exists($r{$k}));
            my $v = wire_rd($h);
            $r{$k} = $v;
        }
        return \%r;
    } else {
        throw RABX::Error("bad type indicator character '$type'", RABX::Error::PROTOCOL);
    }
}

=item call_string FUNCTION ARGS

Return the string used to call FUNCTION with ARGS.

=cut
sub call_string ($$) {
    my ($func, $args) = @_;
    throw RABX::Error("arguments should be reference to list, not " . ref($args), RABX::Error::INTERFACE)
        unless (ref($args) eq 'ARRAY');
    my $buf = '';
    my $h = new IO::String($buf);
    $h->print('R');
    netstring_wr(PROTOCOL_VERSION, $h);
    netstring_wr($func, $h);
    wire_wr($args, $h);
    return $buf;
}

=item call_string_parse STRING

Parse a call string, returning in list context the name of the method called
and a reference to a list of arguments.

=cut
sub call_string_parse ($) {
    if ($have_fast_serialisation) {
        return RABX::Fast::do_call_string_parse($_[0]);
    } else {
        my $h = new IO::String($_[0]);
        my $c = $h->getc();
        throw RABX::Error(qq#EOF reading call string indicator character#, RABX::Error::PROTOCOL)
            if (!defined($c));
        throw RABX::Error(qq#first byte of call string should be "R", not "$c"#, RABX::Error::PROTOCOL)
            unless ($c eq 'R');
        my $ver = netstring_rd($h);
        throw RABX::Error(qq#Bad version "$ver"#, RABX::Error::PROTOCOL) unless ($ver eq PROTOCOL_VERSION);
        my $func = netstring_rd($h);
        my $args = wire_rd($h);
        throw RABX::Error(qq#function arguments should be list, not # . ref($args), RABX::Error::PROTOCOL)
            unless (ref($args) eq 'ARRAY');
        return ($func, $args);
    }
}

=item return_string VALUE

=item return_string ERROR

Return the string used to encode a successfuly function return of VALUE; or, an
error return in the case where the passed value is of type RABX::Error or a
derivative.

=cut
sub return_string ($) {
    if ($have_fast_serialisation) {
        if (ref($_[0]) and UNIVERSAL::isa($_[0], 'RABX::Error')) {
            return RABX::Fast::do_return_string_error($_[0]->value() | RABX::Error::SERVER, $_[0]->text(), $_[0]->can('extradata') ? $_[0]->extradata() : undef);
        } else {
            return RABX::Fast::do_return_string_success($_[0]);
        }
    } else {
        my ($v) = @_;
        my $buf = '';
        my $h = new IO::String($buf);
        if (ref($v) and UNIVERSAL::isa($v, 'RABX::Error')) {
            $h->print('E');
            netstring_wr(PROTOCOL_VERSION, $h);
            netstring_wr($v->value() | RABX::Error::SERVER, $h);    # Indicate that error was detected on server side.
            netstring_wr($v->text(), $h);
            wire_wr($v->extradata(), $h) if ($v->can('extradata'));
        } else {
            $h->print('S');
            netstring_wr(PROTOCOL_VERSION, $h);
            wire_wr($v, $h);
        }
        return $buf;
    }
}

=item return_string_parse STRING

Parse a return string. If it indicates success, return the value; if it is an
error, throw a corresponding RABX::Error.

=cut
sub return_string_parse ($) {
    my ($buf) = @_;
    my $h = new IO::String($buf);
    my $c = $h->getc();
    throw RABX::Error(qq#EOF reading return indicator character#, RABX::Error::PROTOCOL)
        if (!defined($c));
    throw RABX::Error(qq#first byte of return string should be "S" or "E", not "$c"#, RABX::Error::PROTOCOL)
        unless ($c =~ m#^[ES]$#);
    my $ver = netstring_rd($h);
    throw RABX::Error(qq#Bad version "$ver"#, RABX::Error::PROTOCOL) unless ($ver eq PROTOCOL_VERSION);
    if ($c eq 'S') {
        return wire_rd($h);
    } else {
        my $value = netstring_rd($h);
        my $text = netstring_rd($h);
        my $extra = undef;
        if (!$h->eof) {
            $extra = wire_rd($h);
        }
        # XXX test $value against proper range
        throw RABX::Error($text, $value, $extra);
    }
}

package RABX::Client;

use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use Regexp::Common qw(URI);

my $rcsid = ''; $rcsid .= '$Id: RABX.pm,v 1.18 2006-05-30 11:16:04 chris Exp $';

=back

=head1 NAME

RABX::Client

=head1 DESCRIPTION

Call RABX methods over HTTP.

=head1 FUNCTIONS

=over 4

=item new URL

Create a new RABX HTTP client for calling remote methods.

=cut
sub new ($$) {
    my ($class, $url) = @_;
    throw RABX::Error(qq("$url" is not a valid URL), RABX::Error::INTERFACE)
        unless ($url =~ m#^$RE{URI}{HTTP}{-scheme => 'https?'}$#);
    my $self = [new LWP::UserAgent(), 0, $url];
    $self->[0]->env_proxy();
    bless($self, $class);
    $self->ua()->agent("RABX::HTTP, $rcsid");
    return $self;
}

=item ua

I<Instance method.> Return the underlying LWP::UserAgent object; use if you
want to configure proxies, etc.

=cut
sub ua ($) {
    return $_[0]->[0];
}

=item usepost [FLAG]

I<Instance method.> Gets and optionally sets the "use HTTP POST" flag. POST
should be used where:

=over 4

=item
you are calling a non-idempotent method;

=item
you are calling a method with private data which should not be logged.

=back

By default, POST is used only where the encoded data are too long to be sent
in a GET request.

=cut
sub usepost ($;$) {
    my ($self, $usepost) = @_;
    if (defined($usepost)) {
        ($usepost, $self->[1]) = ($self->[1], $usepost);
        return $usepost;
    } else {
        return $self->[1];
    }
}

=item url

I<Instance method.> Get/set the "proxy" URL.

=cut
sub url ($;$) {
    my ($self, $url) = @_;
    if (defined($url)) {
        ($url, $self->[2]) = ($self->[2], $url);
        return $url;
    } else {
        return $self->[2];
    }
}

=item call FUNCTION [ARGUMENT ...]

I<Instance method.> Call a remote FUNCTION via URL with the given ARGUMENTs.

=cut
sub call ($$@) {
    my ($self, $function, @args) = @_;

    # Marshall the call data.
    my $c = RABX::call_string($function, \@args);

    # Decide how to make the call.
    my $usepost = $self->usepost();
    my $c_enc;
    if (!$usepost) {
        $c_enc = $c;
        $c_enc =~ s#([^A-Za-z0-9/,-])#sprintf('%%%02x', ord($1))#gesi;
        $usepost = 1 if (length($c_enc) + length($self->url()) > 1024);
    }

    my $req = new HTTP::Request();
    $req->method($usepost ? 'POST' : 'GET');

    if ($usepost) {
        $req->uri($self->url());
        $req->header('Content-Type', 'application/octet-stream');
        $req->content($c);
    } else {
        $req->uri($self->url() . "?" . $c_enc);
    }

    my $resp = $self->ua()->request($req);

    if (!$resp->is_success()) {
        throw RABX::Error("HTTP error: " . $resp->status_line(), RABX::Error::TRANSPORT);
    } else {
        return RABX::return_string_parse($resp->content());
    }
}

package RABX::Server::CGI;

use CGI;
use Error qw(:try);

=back

=head1 NAME

RABX::Server

=head1 DESCRIPTION

Serve RABX methods from a CGI/FastCGI script.

=head1 FUNCTIONS

=over 4

=item dispatch FUNCTION SPEC [...]

Serve requests for each of the named FUNCTIONs. SPEC is either a reference to
the function to be called, or a reference to a list of the function ref and a
maximum cache age in seconds.

=cut
sub dispatch (%) { # XXX should take stream + environment hash
    my (%funcs) = @_;
    my $ret;

    binmode(STDIN);
    binmode(STDOUT);

    my $maxage = 0;

    try {
        my $meth = $ENV{REQUEST_METHOD};
        throw RABX::Error(qq#No REQUEST_METHOD in environment; this script must be run in a CGI/FastCGI context#, RABX::Error::INTERFACE)
            if (!defined($meth));
        throw RABX::Error(qq#Bad HTTP method "$meth"; should be "GET" or "POST"#, RABX::Error::TRANSPORT)
            if ($meth !~ m#^(GET|POST)$#);
        my $callstr;
        if ($meth eq 'GET') {
            $callstr = $ENV{QUERY_STRING};
            $callstr =~ s#\+# #gs;
            $callstr =~ s#%([0-9a-f][0-9a-f])#sprintf('%c', hex($1))#gesi;
        } else {
            my $l = $ENV{CONTENT_LENGTH};
            throw RABX::Error(q#Bad or missing Content-Length header in POST#, RABX::Error::TRANSPORT)
                if (!defined($l) or $l =~ m#[^\d]#);
            $callstr = '';
            while (length($callstr) < $l) {
                my $n = STDIN->read($callstr, $l - length($callstr), length($callstr));
                throw RABX::Error(qq#$! reading POST data#, RABX::Error::TRANSPORT)
                    if (!defined($n));
                throw RABX::Error(qq#EOF reading POST data#, RABX::Error::TRANSPORT)
                    if ($n == 0);
            }
        }

        my ($func, $args) = RABX::call_string_parse($callstr);
        throw RABX::Error(qq#no function "$func"#, RABX::Error::INTERFACE)
            if (!exists($funcs{$func}));

        # Now actually call the function.
        my $x = $funcs{$func};
        if (ref($x) eq 'ARRAY') {
            $maxage = $x->[1];
            $x = $x->[0];
        }
        $ret = $x->(@$args);
    } catch RABX::Error with {
        $ret = shift;
    } otherwise {
        my $E = shift;
        $ret = new RABX::Error("$E", RABX::Error::UNKNOWN);
    };

    my $retstr = RABX::return_string($ret);
    print "Content-Type: application/octet-stream\n",
          "Content-Length: ",  length($retstr), "\n";
    print "Cache-Control: max-age=$maxage\n" if ($maxage);
    print "\n",
          $retstr;
}

1;
