#!/usr/bin/env python2.5
#
# utils.py:
# Some non site specific utility functions
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: duncan@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: utils.py,v 1.1 2009-09-28 10:10:43 duncan Exp $
#

import re

# Prettifying functions
def canonicalise_postcode(postcode):
    postcode = re.sub('[^A-Z0-9]', '', postcode.upper())
    postcode = re.sub('(\d[A-Z]{2})$', r' \1', postcode)
    return postcode
