#!/usr/bin/perl -w
#
# mySociety/Locale.pm:
# I18n with Perl
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: Locale.pm,v 1.12 2009-09-10 12:16:02 matthew Exp $

package mySociety::Locale;

use strict;
use FindBin;
use HTTPNegotiate;
use Locale::gettext;
use POSIX qw(setlocale LC_ALL);

my $gettext;

# Note, that this function is forced into the main namespace
# as Perl treats the _ function as magic
sub _ {
    return $gettext->get($_[0]);
}

sub nget {
    return $gettext->nget(@_);
}

our %langmap = ();
our %langs = ();
our $lang;

# negotiate_language CONFIG OVERRIDE
# Sets $lang to negotiated language.
# CONFIG is string from config file containing list of available languages.
#        e.g. 'en-gb,English,en_GB|pt-br,Portugu&ecirc;s (Brasil),pt_BR'
# OVERRIDE is override language, such as from cookie or domain name.  Set to
# null to force negotiation of language from browser, using HTTP headers. */
sub negotiate_language($;$) {
    my ($available_language_config, $override_language) = @_;
    my @opt_langs = split /\|/, $available_language_config;
    my $variants = [];
    foreach my $opt_lang (@opt_langs) {
        my ($code, $verbose, $locale) = split /,/, $opt_lang;
        $langs{$code} = $verbose;
        $langmap{$code} = $locale;
        push @$variants, [$code, undef, undef, undef, undef, $code, undef];
    }
    if ($override_language && $langs{$override_language}) {
        $lang = $override_language;
    } else {
        local $^W = 0;
        $lang = HTTP::Negotiate::choose($variants);
        if (!$lang || !$langmap{$lang}) {
            $lang = 'en-gb'; # Default override
        }
    }
    return $lang;
}

# change LANG
# Change human language to display text, dates, numbers etc. in. LANG is the
# keys from the available language string previously passed to
# negotiate_language. Leave unset to use the default negotiated language.
my $current = '';
sub change(;$) {
    my $l = shift || '';
    $l = $lang if $l eq "";
    return if $l eq $current;
    my $os_locale = $langmap{$l}.'.UTF-8';
    delete $ENV{LANGUAGE}; # clear this if set
    $ENV{LANG} = $os_locale;
    my $ret = setlocale(LC_ALL, $os_locale);
    die "setlocale failed for $os_locale" if $ret ne $os_locale;
    $current = $l;
    # Clear gettext's cache - you have to do this when
    # you change environment variables.
    # textdomain(textdomain(NULL));
}

# push LANG, pop
# Change locale using a stack system, so you can easily restore to whatever
# locale was previously set.
my @stack = ();
sub push($) {
    my $l = shift;
    push @stack, $current;
    change($l);
}
sub pop() {
    my $l = pop @stack;
    change($l);
}

# in_gb_locale FUNCTION-REF
# If you need something to be done in an English locale (for example,
# generating email headers, or requesting a URL with decimal numbers),
# this decorator will do that for you.
sub in_gb_locale(&) {
    my $sub = shift;
    mySociety::Locale::push('en-gb') if $lang;
    my (@result, $result);
    wantarray ? @result = $sub->() : $result = $sub->();
    mySociety::Locale::pop() if $lang;
    return wantarray ? @result : $result;
}

# gettext_domain DOMAIN [UNICODE]
# Set gettext domain. e.g. 'PledgeBank'
# Set UNICODE if you want Unicode strings returned, not octets.
sub gettext_domain($;$) {
    my ($domain, $unicode) = @_;
    $gettext = $unicode ? Locale::gettext->domain($domain) : Locale::gettext->domain_raw($domain);
    die "failed to bind to gettext domain $domain" unless $gettext;
    $gettext->dir("$FindBin::Bin/../locale");
    $gettext->codeset('UTF-8') unless $unicode;
}

1;
