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
import mysociety.rabx

def call_old(*params):
    base_url = mysociety.config.get("MAPIT_URL")
    return mysociety.rabx.call_rest_rabx(base_url, params)

BAD_POSTCODE = 2001        #    String is not in the correct format for a postcode. 
POSTCODE_NOT_FOUND = 2002        #    The postcode was not found in the database. 
AREA_NOT_FOUND = 2003        #    The area ID refers to a non-existent area. 

def get_voting_areas(postcode):
    result = call_old('get_voting_areas', postcode)
    return result

def get_voting_area_info(area):
    result = call_old('get_voting_area_info', area)
    return result

def get_voting_areas_info(ary):
    result = call_old('get_voting_areas_info', ary)
    return result

def get_voting_area_by_name(name, type = None, min_generation = None):
    result = call_old('get_voting_area_by_name', name, type, min_generation)
    return result

def get_voting_areas_by_location(coordinate, method, types = None, generation = None):
    result = call_old('get_voting_areas_by_location', coordinate, method, types, generation)
    return result

def get_areas_by_type(type, min_generation = None):
    result = call_old('get_areas_by_type', type, min_generation)
    return result

def get_example_postcode(id):
    result = call_old('get_example_postcode', id)
    return result

def get_voting_area_children(id):
    result = call_old('get_voting_area_children', id)
    return result

def get_location(postcode, partial = None):
    result = call_old('get_location', postcode, partial)
    return result

def call(url):
    full_url = urlparse.urljoin(mysociety.config.get('MAPIT_URL'), url)
    api_key = mysociety.config.get('MAPIT_API_KEY', '')
    if api_key:
        headers = {'X-Api-Key': api_key}
    else:
        headers = {}
    request = urllib2.Request(full_url, headers=headers)
    return urllib2.urlopen(request)
