#!/usr/bin/perl -w

use strict;
use HTML::Entities;

my %langs = (
    'be_BY' => 'be',
    'cy_GB' => 'cy',
    'de_DE' => 'de',
    'en_GB' => 'en-gb',
    'eo_XX' => 'eo',
    'es_ES' => 'es',
    'et_EE' => 'et',
    'fi_FI' => 'fi',
    'fr_FR' => 'fr',
    'it_IT' => 'it',
    'ja_JP' => 'ja',
    'nl_BE' => 'nl-be',
    'nl_NL' => 'nl',
    'pa_IN' => 'pa',
    'pl_PL' => 'pl',
    'pt_BR' => 'pt-br',
    'ru_RU' => 'ru',
    'sk_SK' => 'sk',
    'uk_UA' => 'uk',
    'zh_CN' => 'zh'
);

for (<locale/*.UTF-8/LC_MESSAGES/PledgeBank*.po>) {
    #print $_ . "\n";
    my ($lang) = /locale\/(.*?)\./;
    my ($microsite) = /PledgeBank(.*?)\.po$/;
    $microsite = ".".(lc $microsite) if $microsite;
    #print $lang . " $microsite\n";
    open(FP, $_) or die $!;
    my $out = '';
    while (<FP>) {
        next unless /^#:.*?pb\.js/;
        my $next;
        do {
            $next = <FP>;
        } while $next =~ /^#:.*?pb\.js/;
        my $fuzzy = 0;
        $fuzzy = 1 if $next =~ /fuzzy/;
        $next = <FP> if $next =~ /^#,/;
        my $msgid = '';
        if ($next =~ /^msgid ""\s+$/) {
            my $l;
            while (($l = <FP>) !~ /msgstr/) {
                chomp($l);
                $msgid .= substr($l, 1, -1);
            }
            $next = $l
        } else {
            ($msgid) = $next =~ /^msgid "(.*)"/;
            $next = <FP>;
        }
        my $msgstr = '';
        if (!$fuzzy) {
            if ($next =~ /^msgstr ""\s+$/) {
                while ((my $l = <FP>) !~ /^\s+$/) {
                    chomp($l);
                    $msgstr .= substr($l, 1, -1);
                }
            } else {
                ($msgstr) = $next =~ /^msgstr "(.*)"/;
            }
        }
	_decode_entities($msgstr, { nbsp => "\xc2\xa0", ocirc => "\xc3\xb4" });
        $out .= "\"$msgid\":\"$msgstr\",\n";
    }
    close FP;
    $out = substr($out, 0, -2);
    open (FP, ">pb/web/js/pb.$langs{$lang}${microsite}.js") or die $!;
    print FP <<EOF;
/*
 * pb.$langs{$lang}.js
 * Translation of JS strings
 * Auto-generated from .po files by gettext-makejs
 *
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: matthew AT mysociety.org. WWW: http://www.mysociety.org/
 *
 */

var translation = {
EOF
    print FP $out;
    print FP "\n}\n";
    close FP;
}

