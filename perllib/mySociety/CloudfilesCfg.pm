use strict;

package mySociety::CloudfilesCfg;

sub get_config {
    # Arg 1: name of config file containing VARIABLE=value pairs

    my $filename=shift(@_);

    open CONFIG, $filename or die "can't open $filename: $!";

    my ($url, $username, $apikey);

    while(<CONFIG>) {
        chomp;
        my ($name, $value)=split /=/;

        $url=$value if($name eq 'CLOUDFILES_AUTHURL');
        $username=$value if($name eq 'CLOUDFILES_USERNAME');
        $apikey=$value if($name eq 'CLOUDFILES_APIKEY');
    }

    close CONFIG;

    die "CLOUDFILES_AUTHURL not defined" if(!defined($url));
    die "CLOUDFILES_USERNAME not defined" if(!defined($username));
    die "CLOUDFILES_APIKEY not defined" if(!defined($apikey));

    return ($url, $username, $apikey);
}

1;
