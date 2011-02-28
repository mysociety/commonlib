use strict;
use warnings;

use Test::More tests => 8;

# locate the sample file to use for testing
my $sample_vhosts = __FILE__;
$sample_vhosts =~ s{\.t$}{_sample.pl};
ok -e $sample_vhosts, "have sample vhosts file '$sample_vhosts'";

# create a new vhosts object from that file
use_ok 'mySociety::VHosts';
my $vhosts = mySociety::VHosts->new( { file => $sample_vhosts } );
is $vhosts->file, $sample_vhosts, "using sample file";

# check some entries are as expected
is(
    $vhosts->site('mysociety')->{user},    #
    'mswww',                               #
    "correct mysociety user"
);
is_deeply(
    $vhosts->vhost('www.mysociety.org')->{servers},    #
    ['arrow'],                                         #
    "correct www.mysociety.org servers"
);
is(
    $vhosts->database('ycml')->{prefix},               #
    'YCML',                                            #
    "got correct database prefix"
);

# check some of the more useful methods - such as finding all dirs to backup
is_deeply(
    $vhosts->all_vhosts_backup_dirs(),                 #
    [
        {
            vhost   => 'www.mysociety.org',
            servers => ['arrow'],
            dir     => '/absolute/path/to/dir',
        },
        {
            vhost   => 'www.mysociety.org',
            servers => ['arrow'],
            dir     => 'relative/path',
        },
        {
            vhost   => 'www.mysociety.org',
            servers => ['arrow'],
            dir     => '../up_one_level',
        },
    ],
    "got all_vhosts_backup_dirs"
);

is_deeply(
    $vhosts->all_vhosts_backup_dirs( { make_dirs_absolute => 1 } ),    #
    [
        {
            vhost   => 'www.mysociety.org',
            servers => ['arrow'],
            dir     => '/absolute/path/to/dir',
        },
        {
            vhost   => 'www.mysociety.org',
            servers => ['arrow'],
            dir     => '/data/vhost/www.mysociety.org/mysociety/relative/path',
        },
        {
            vhost   => 'www.mysociety.org',
            servers => ['arrow'],
            dir => '/data/vhost/www.mysociety.org/mysociety/../up_one_level',
        },
    ],
    "got all_vhosts_backup_dirs (using make_dirs_absolute=>1)"
);
