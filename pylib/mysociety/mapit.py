# mapit.py:
# Client interface for MaPit
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org
#
# $Id: mapit.py,v 1.2 2009-11-30 13:11:03 matthew Exp $
#

import urllib2
import urlparse

import mysociety.config

def call(url):
    full_url = urlparse.urljoin(mysociety.config.get('MAPIT_URL'), url)
    api_key = mysociety.config.get('MAPIT_API_KEY', '')
    if api_key:
        headers = {'X-Api-Key': api_key}
    else:
        headers = {}
    request = urllib2.Request(full_url, headers=headers)
    return urllib2.urlopen(request)
