#
# Memcached.pm:
# Slight subclass of Memcached to simplify namespacing.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Memcached.pm,v 1.2 2010-03-12 19:22:31 matthew Exp $
#

package mySociety::Memcached;

use strict;
use Cache::Memcached;

my ($memcache, $server, $namespace);

sub set_config {
    $server = shift;
    $namespace = shift;
}

sub cache_connect {
    $memcache = new Cache::Memcached {
        'servers' => [ "$server:11211" ],
        'namespace' => $namespace,
        'debug' => 0,
        'compress_threshold' => 10_000,
    };
}

# Create copies of Cache::Memcached methods that connect on first use
foreach (qw/get get_multi set add replace delete incr decr flush_all/) {
    eval <<EOF;
sub $_ {
    cache_connect() unless \$memcache;
    \$memcache->$_(\@_);
}
EOF
}

1;
