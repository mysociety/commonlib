#!/usr/bin/perl                                                                                                                
use strict;

package mySociety::S3Cfg;

# Subroutine for getting the AWS key and secret from an s3cfg file                                                             
sub get_aws_keys_from_s3cfg {
    # Takes one argument - a path to an s3cmd config file                                                                      
    my $s3cfg = shift(@_);

    open(S3CFG, "<", $s3cfg) or die("Couldn't open $s3cfg");

    my $aws_key;
    my $aws_secret;

    while (my $line = <S3CFG>) {
        chomp($line);

        if ($line =~ /\s*access_key\s*=\s*(\S*)\s*/) {
            $aws_key = $1;
        }
        elsif ($line =~ /\s*secret_key\s*=\s*(\S*)\s*/) {
            $aws_secret = $1;
        }
    };

    die "No AWS key found" unless defined($aws_key);
    die "No AWS secret found" unless defined($aws_secret);

    return ($aws_key, $aws_secret)
};

1;
