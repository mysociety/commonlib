#
# rabx.py:
# Client side functions to call RABX services, but via REST/JSON, rather than
# using netstrings as for older Perl/PHP clients.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: rabx.py,v 1.2 2009-02-26 09:46:02 francis Exp $
#

import os
import subprocess
import re
import json
import urllib

class RABXException(Exception):
    def __init__(self, value, text, extradata):
        self.value = value
        self.text = text
        self.extradata = extradata

    def __str__(self):
        ret = str(self.value) + ": " + self.text
        if self.extradata:
            ret = ret + str(self.extradata)
        return ret

def call_rest_rabx(base_url, params):
    params = [ '' if x == None else x for x in params ]
    params_quoted = [ urllib.quote_plus(x) for x in params ]
    params_joined = "/".join(params_quoted)
    url = base_url.replace(".cgi", "-rest.cgi") + "?" + params_joined
    content = urllib.urlopen(url).read()
    result = json.read(content)
    if 'error_value' in result:
        raise RABXException(result['error_value'], result['error_text'], result['error_extradata'] if 'error_extradata' in result else None)
    return result


