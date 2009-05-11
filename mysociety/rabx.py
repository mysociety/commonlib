#
# rabx.py:
# Client side functions to call RABX services, but via REST/JSON, rather than
# using netstrings as for older Perl/PHP clients.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: rabx.py,v 1.5 2009-05-11 22:17:40 matthew Exp $
#

import os
import subprocess
import re
import simplejson
import urllib

class RABXException(Exception):
    def __init__(self, value, text, extradata):
        self.value = int(value)
        self.text = text
        self.extradata = extradata

    def __str__(self):
        ret = str(self.value) + ": " + self.text
        if self.extradata:
            ret = ret + str(self.extradata)
        return ret

def call_rest_rabx(base_url, params_init):
    params = []
    for p in params_init:
        if p == None:
            params.append('')
        else:
            params.append(p)
    params_quoted = [ urllib.quote_plus(x) for x in params ]
    params_joined = "/".join(params_quoted)
    url = base_url.replace(".cgi", "-rest.cgi") + "?" + params_joined
    content = urllib.urlopen(url).read()
    result = simplejson.loads(content)
    if 'error_value' in result:
        raise RABXException(result['error_value'], result['error_text'], result.get('error_extradata'))
    return result


