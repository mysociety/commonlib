use strict;
use warnings;

use Test::More tests => 2;

use_ok 'mySociety::HTMLUtil';

is(
    mySociety::HTMLUtil::ms_make_clickable(
        "Test www.example.com/a\tfoo\@example.com\tstyle=color:red"
    ),
    'Test <a href="http://www.example.com/a" rel="nofollow">'
      . "www.example.com/a</a>\t"
      . '<a href="mailto:foo@example.com">foo@example.com</a>'
      . "\tstyle=color:red",
    "keeps tab separated text out of links"
);
