#
# atcocif.py:
# ATCO-CIF transport journey file loader.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: atcocif.py,v 1.1 2008-07-31 08:47:17 francis Exp $
#

"""
Load files in the ATCO-CIF file format, which is used in the UK to specify
public transport journeys for accessibility planning by the National Public
Transport Data Repository (NPTDR).
Specification is here: http://www.pti.org.uk/CIF/atco-cif-spec.pdf 
"""

import os
import sys
import re
import datetime
import mx.DateTime

###########################################################
# Main class

class ATCO:
    # Load in an ATCO-CIF file, parsing ever record
    def read(self, f):
        """read(FILE) ->
           
           FILE is the name of the ATCO-CIF file to load in.
        """

        self.handle = open(f)

        line = self.handle.readline().strip("\n\r")
        self.file_header = FileHeader(line)
        print self.file_header

        self.records = []
        for line in self.handle.readlines():
            line = line.strip("\n\r")
            record_identity = line[0:2]
            if record_identity == 'QS':
                record = JourneyHeader(line)
            elif record_identity == 'QO':
                record = JourneyOrigin(line)
            else:
                raise Exception("Unknown record type " + record_identity)
            print record
            self.records.append(record)

###########################################################
# Helper functions
def parse_time(time_string):
    return datetime.time(int(time_string[0:2]), int(time_string[2:4]), 0)

def parse_date(date_string):
    return datetime.date(
        int(date_string[0:4]), int(date_string[4:6]), int(date_string[6:8]),
    )

def parse_date_time(date_string, time_string):
    return datetime.datetime(
        int(date_string[0:4]), int(date_string[4:6]), int(date_string[6:8]),
        int(time_string[0:2]), int(time_string[2:4]), 0
    )

#return mx.DateTime.DateTimeFrom(date_string + " " + time_string)

###########################################################
# Record classes

# Base class of individual records from the ATCO-CIF file. Stores the line of
# text the the derived classes parser into members of the class.
class CIFRecord:
    def __init__(self, line, record_identity):
        self.line = line
        self.record_identity = line[0:2]
        assert self.record_identity == record_identity

    def __repr__(self):
        ret = self.line + "\n"
        keys = self.__dict__.keys()
        keys.sort()
        for key in keys:
            if key != 'line':
                ret = ret + "\t" + key + ": " + repr(self.__dict__[key]) + "\n"
        return ret

# Main header of whole file
class FileHeader(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "AT")

        matches = re.match('^ATCO-CIF(\d\d)(\d\d)(.{32})(.{16})(\d{8})(\d{6})$', line) 
        if not matches:
            raise Exception("ATCO-CIF header line incorrectly formatted: " + line)
        self.version_major = int(matches.group(1))
        self.version_minor = int(matches.group(2))
        self.file_originator = matches.group(3).strip()
        self.source_product = matches.group(4).strip()
        self.production_datetime = parse_date_time(matches.group(5), matches.group(6))

# Header of a journey record
class JourneyHeader(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QS")

        matches = re.match('^QS([NDR])(.{4})(.{6})(.{8})(.{8})([01]{7})([ SH])([ ABX])(.{4})(.{6})(.{8})(.{8})(.)$', line)
        if not matches:
            raise Exception("Journey header line incorrectly formatted: " + line)

        self.transaction_type = matches.group(1)
        self.operator = matches.group(2).strip()
        self.unique_journey_identifier = matches.group(3).strip()
        self.first_date_of_operation = parse_date(matches.group(4))
        self.last_date_of_opreation = parse_date(matches.group(5))
        self.operates_on_day_of_week = [None] * 8
        day_of_week_group = matches.group(6)
        for day_of_week in range(1, 8):
            self.operates_on_day_of_week[day_of_week] = bool(int(day_of_week_group[day_of_week - 1]))
        self.school_term_time = matches.group(7)
        self.bank_holidays = matches.group(8)
        self.route_number = matches.group(9)
        self.running_board = matches.group(10).strip()
        self.vehicle_type = matches.group(11).strip()
        self.registration_number = matches.group(12).strip()
        self.route_direction = matches.group(13)

# Origin of journey route
class JourneyOrigin(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QO")

        matches = re.match('^QO(.{12})(.{4})(.{3})(T[01])(F0|F1|  )$', line)
        if not matches:
            raise Exception("Journey origin line incorrectly formatted: " + line)

        self.location = matches.group(1).strip()
        self.published_departure_time = parse_time(matches.group(2))
        self.bay_number = matches.group(3)
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(4)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(5)]
 

