#!/usr/bin/perl -w -I../perllib

# test.pl
# Script for quick hacky testing of Perl stuff
#
# Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: test.pl,v 1.2 2009-01-26 14:21:50 matthew Exp $

use mySociety::Config;

mySociety::Config::set_file("/home/francis/devel/mysociety/fyr/conf/general");

print mySociety::Config::get("OPTION_DADEM_URL") . "\n";
print mySociety::Config::get("OPTION_MAPIT_URL") . "\n";


