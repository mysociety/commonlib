$sites = {
    'mysociety' => {
        user        => 'mswww',
        web_dir     => 'ms/web',
        cvs_dirs    => [ 'ms', 'perllib', 'phplib' ],
        cvs_user    => 'anon',
        conf_dir    => 'ms/conf',
        exec_extras => {
            user => [
'if [ ! -e ms/web/wp ]; then svn co http://core.svn.wordpress.org/tags/3.0.5 ms/web/wp; fi',
'cp -pfu ms/web/wordpress_2_8_2/wp-config.php ms/web/wp/wp-config.php',
'cp -rpfu ms/web/wordpress_2_8_2/wp-content/* ms/web/wp/wp-content',
            ]
        },
        stats => 1,
    },
};

$vhosts = {
    'www.mysociety.org' => {
        site    => 'mysociety',
        staging => 0,
        servers => ['arrow'],
        redirects =>
          [ 'mysociety.org', 'mysociety.co.uk', 'www.mysociety.co.uk' ],
        crontab   => 1,
        user      => 'mswww',
        cvs_user  => 'anon',
        databases => ['msorg'],
        backup_dirs =>
          [ '/absolute/path/to/dir', 'relative/path', '.' ],
    },
};

$databases = {
    'ycml' => {
        prefix => 'YCML',
        type   => 'psql',
        host   => 'phoenix',
        port   => '5434',
        backup => 1,
    },
};

