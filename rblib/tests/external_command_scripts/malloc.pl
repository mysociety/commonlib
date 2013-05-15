#!/usr/bin/perl
#
# Allocate 512MB of memory.
#
# Note that this allocates twice as much as you'd expect:
# once to build the string, and again to copy it to the variable.
#

$a = 'a' x (1048576 * 512);
print "OK\n";
