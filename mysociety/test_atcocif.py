#!/usr/bin/python
#
# test_atcocif.py:
# Test ATCO-CIF transport journey file loader.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: test_atcocif.py,v 1.1 2009-02-04 17:41:40 francis Exp $
#

import unittest
from test import test_support

import atcocif

class TestBadHeaders(unittest.TestCase):
    def setUp(self):
        self.atco = atcocif.ATCO()

    def test_missing_file_header(self):
        self.assertRaises(Exception, lambda: self.atco.read_string(u"""nonsense"""))


def test_main():
    test_support.run_unittest(TestBadHeaders
                              # ... list other tests ...
                             )

if __name__ == '__main__':
    test_main()

