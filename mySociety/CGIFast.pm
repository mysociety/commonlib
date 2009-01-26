#!/usr/bin/perl
#
# mySociety/CGIFast.pm
# Modified version of CGI::Fast to handle signals correctly
# and fail on an interrupt in accept()
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: CGIFast.pm,v 1.3 2009-01-26 14:21:51 matthew Exp $
#
# Copyright 1995,1996, Lincoln D. Stein.  All rights reserved.
# It may be used and modified freely, but I do request that this copyright
# notice remain attached to the file.  You may modify this module as you 
# wish, but if you redistribute a modified version, please attach a note
# listing the modifications you have made.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.

package mySociety::CGIFast;

use strict;
use CGI;
use FCGI;
our @ISA = ('CGI');

# workaround for known bug in libfcgi
while ((my $ignore) = each %ENV) { }

# override the initialization behavior so that
# state is NOT maintained between invocations 
sub save_request {
    # no-op
}

use vars qw($Ext_Request);
BEGIN {
   # If ENV{FCGI_SOCKET_PATH} is given, explicitly open the socket,
   # and keep the request handle around from which to call Accept().
   if ($ENV{FCGI_SOCKET_PATH}) {
	my $path    = $ENV{FCGI_SOCKET_PATH};
	my $backlog = $ENV{FCGI_LISTEN_QUEUE} || 100;
	my $socket  = FCGI::OpenSocket( $path, $backlog );
	$Ext_Request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, 
					\%ENV, $socket, 1 );
   } else {
	# Create a default request handle, with fail on interrupt set
	$Ext_Request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR,
					\%ENV, 0, 1 );
   }
}

# Signal handling, so as to die after current request, not during
my $exit_requested = 0;
$SIG{TERM} = $SIG{USR1} = sub {
    $exit_requested = 1;
};

sub new {
     my ($self, $initializer, @param) = @_;
     return undef if $exit_requested;
     unless (defined $initializer) {
	if ($Ext_Request) {
          return undef unless $Ext_Request->Accept() >= 0;
	} else {
         return undef unless FCGI::accept() >= 0;
     }
     }
     # CGI::Fast 1.07 calls _reset_globals, this is a slight improvement
     my $x = $CGI::XHTML;
     CGI->initialize_globals;
     $CGI::XHTML = $x;
     return $CGI::Q = $self->SUPER::new($initializer, @param);
}

1;
