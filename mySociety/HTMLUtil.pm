#!/usr/bin/perl
#
# mySociety/HTMLUtil.pm
# Utilities for HTML, php, split from mySociety::Util.
#

package mySociety::HTMLUtil;

use strict;

BEGIN {
    use Exporter ();
    our @ISA = qw(Exporter);
    our @EXPORT_OK = qw();
}
our @EXPORT_OK;

=head1 NAME

mySociety::HTMLUtil

head1 DESCRIPTION

Utilities for HTML, php, split from mySociety::Util.

=head FUNCTIONS

=over 4

=item ms_make_clickable TEXT

Returns TEXT with obvious links made into HTML hrefs. 

Taken from WordPress via mysociety/phplib/utility.php, tweaked slightly to work
with , and . at end of some URLs.

=cut
sub ms_make_clickable {
    my ($ret) = @_;
    my $contract = 1;

    $ret = ' ' . $ret . ' ';
    $ret =~ s#(https?)://([^\s<>{}()]+[^\s.,<>{}()])#<a href='$1://$2' rel='nofollow'>$1://$2</a>#ig;
    $ret =~ s#(\s)www\.([a-z0-9\-]+)((?:\.[a-z0-9\-\~]+)+)((?:/[^ <>{}()\n\r]*[^., <>{}()\n\r])?)#$1<a href='http://www.$2$3$4' rel='nofollow'>www.$2$3$4</a>#ig;
    if ($contract) {
        $ret =~ s#(<a href='[^']*'>)([^<]{40})[^<]*?</a>#$1$2...</a>#g;
    }
    $ret =~ s#(\s)([a-z0-9\-_.]+)@([^,< \n\r]*[^.,< \n\r])#$1<a href=\"mailto:$2@$3\">$2@$3</a>#gi;
    
    # trim
    $ret =~ s#^\s+##;
    $ret =~ s#\s+$##;
    return $ret;
}

=item nl2br TEXT

Returns TEXT with newlines converted to <br>.

Implementation of nl2br in PHP.
=cut
sub nl2br {
    my ($ret) = @_;
    $ret =~ s/\r\n/\n/g;
    $ret =~ s#\n#<br />\n#g;
    return $ret;
}

1;
