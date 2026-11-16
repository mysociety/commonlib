<?php

require_once dirname(__FILE__) . '/../utility.php';

$text = "Test www.example.com/a\tfoo@example.com\tstyle=color:red";
$expected = 'Test <a href="http://www.example.com/a" rel="nofollow">'
    . "www.example.com/a</a>\t"
    . '<a href="mailto:foo@example.com">foo@example.com</a>'
    . "\tstyle=color:red";
$actual = ms_make_clickable($text, array('nofollow' => true));

if ($actual !== $expected) {
    fwrite(STDERR, "ms_make_clickable keeps tab separated text out of links\n"
        . "expected: $expected\n  actual: $actual\n");
    exit(1);
}

echo "ok\n";
