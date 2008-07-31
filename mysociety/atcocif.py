#
# atcocif.py:
# ATCO-CIF transport journey file loader.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: atcocif.py,v 1.3 2008-07-31 17:19:55 francis Exp $
#

# TODO:
# Look at the transaction types, are they always nice?
# Allow for the interchange time at the end :) - currently we'll always arrive early by that time
# timetz - what about time zones!  http://docs.python.org/lib/datetime-datetime.html
#
# Work out correct date to use, which week in October is the data set valid for?
# Journeys over midnight will be knackered, no idea how ATCO-CIF even stores them
# Do all trains have T for activity_flag? They should have pick up only for some cases, Matthew says:
#    london-brum will be pick up only at watford
#    manchester-london will be pick up only at stockport

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
import logging

###########################################################
# Main class

class ATCO:
    # train_interchange_default - time in minutes to allow by default to change trains at same station
    # bus_interchange_default - likewise for buses, at exact same stop
    def __init__(self, train_interchange_default = 5, bus_interchange_default = 1):
        self.train_interchange_default = train_interchange_default
        self.bus_interchange_default = bus_interchange_default

        self.journeys = []
        self.locations = []

    def __str__(self):
        ret = str(self.file_header) + "\n"
        for journey in self.journeys:
            ret = ret + str(journey) + "\n"
        for location in self.locations:
            ret = ret + str(location) + "\n"
        return ret
    
    # Load in an ATCO-CIF file, parsing ever record
    def read(self, f):
        """read(FILE) ->
           
           FILE is the name of the ATCO-CIF file to load in.
        """

        self.handle = open(f)

        line = self.handle.readline().strip("\n\r")
        self.file_header = FileHeader(line)

        # Load in every record - each record is one line of the file
        current_item = None
        for line in self.handle.readlines():
            line = line.strip("\n\r")
            #print line
            record_identity = line[0:2]
            record = None

            # Journeys - store the clump of records relating to one journey 
            if record_identity == 'QS':
                current_item = JourneyHeader(line)
                self.journeys.append(current_item)
            elif record_identity == 'QO':
                assert isinstance(current_item, JourneyHeader)
                current_item.add_hop(JourneyOrigin(line))
            elif record_identity == 'QI':
                assert isinstance(current_item, JourneyHeader)
                current_item.add_hop(JourneyIntermediate(line))
            elif record_identity == 'QT':
                assert isinstance(current_item, JourneyHeader)
                current_item.add_hop(JourneyDestination(line))
            
            # Locations - store the group of records relating to one location
            elif record_identity == 'QL':
                current_item = Location(line)
                self.locations.append(current_item)
            elif record_identity == 'QB':
                assert isinstance(current_item, Location)
                current_item.add_additional(LocationAdditional(line))

            # Other
            elif record_identity in ['QV', 'QD']:
                logging.warning("Ignoring record type " + record_identity)
            else:
                raise Exception("Unknown record type " + record_identity)

    # Make dictionaries so it is quick to look up all journeys visiting a particular location etc.
    def index_by_short_codes(self):
        self.journeys_visiting_location = {}
        for journey in self.journeys:
            for hop in journey.hops:
                if hop.location not in self.journeys_visiting_location:
                    self.journeys_visiting_location[hop.location] = set()

                assert journey not in self.journeys_visiting_location[hop.location], "same location appears twice in one journey"
                self.journeys_visiting_location[hop.location].add(journey)

    # Adjacency function for use with Dijkstra's algorithm on earliest time to arrive somewhere.
    # Given a location (string short code) and a date/time, it finds every
    # other station you can get there on time by one direct train/bus. 
    def adjacent_location_times(self, location, target_arrival_datetime):
        logging.debug("adjacent_location_times location: " + location + " target_arrival_datetime: " + str(target_arrival_datetime))
        if location not in self.journeys_visiting_location:
            raise Exception, "No journeys known visiting location " + location

        # ret is dictionary from location to time at that location
        ret = {}
        for journey in self.journeys_visiting_location[location]:
            logging.debug("\tconsidering journey: " + journey.unique_journey_identifier)

            # Check whether the journey runs on the relevant date
            # XXX assumes we don't do journeys over midnight
            (valid_on_date, reason) = journey.is_valid_on_date(target_arrival_datetime.date()) 
            if not valid_on_date:
                logging.debug("\t\tnot valid on date: " + reason)
            else:
                # Find out when it arrives at this stop
                arrival_time_at_location = journey.find_arrival_time_at_location(location)
                logging.debug("\t\tarrival time at location: " + str(arrival_time_at_location))
                arrival_datetime_at_location = datetime.datetime.combine(target_arrival_datetime.date(), arrival_time_at_location)

                # Work out how long we need to allow to change at the stop
                # XXX here need to know if the stop is the last destination stop, as you don't need interchange time
                if journey.vehicle_type == 'TRAIN':
                    interchange_time_in_minutes = self.train_interchange_default
                elif journey.vehicle_type == 'BUS': # XXX not tested
                    interchange_time_in_minutes = self.bus_interchange_default
                else:
                    assert False, "unknown vehicle type for working out interchange time default: %s" % journey.vehicle_type
                interchange_time = datetime.timedelta(0, interchange_time_in_minutes * 60)
                
                # See whether if we want to use this journey to get to this
                # stop, we get there on time to change to the next journey.
                if arrival_datetime_at_location + interchange_time > target_arrival_datetime:
                    logging.debug("\t\twhich is too late with interchange time %s, so not using journey" % str(interchange_time))
                else:
                    logging.debug("\t\tadding stops...")
                    # Now go through every earlier stop, and add it to the list of returnable nodes

                    # remember to catch midnight case
                                 

        return ret
            

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
# Individual record classes

# Base class of individual records from the ATCO-CIF file. Stores the line of
# text the the derived classes parser into members of the class.
class CIFRecord:
    def __init__(self, line, record_identity):
        self.line = line
        self.record_identity = line[0:2]
        assert self.record_identity == record_identity

    def __str__(self):
        ret = self.__class__.__name__ + "\n"
        ret = ret + "\tline: " + self.line + "\n"
        keys = self.__dict__.keys()
        keys.sort()
        for key in keys:
            if key != 'line' and key != 'hops':
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

# Header of a journey record, stores all associated records too (in self.hops)
class JourneyHeader(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QS")

        matches = re.match('^QS([NDR])(.{4})(.{6})(\d{8})(\d{8})([01]{7})([ SH])([ ABX])(.{4})(.{6})(.{8})(.{8})(.)$', line)
        if not matches:
            raise Exception("Journey header line incorrectly formatted: " + line)

        self.transaction_type = matches.group(1)
        self.operator = matches.group(2).strip()
        self.unique_journey_identifier = matches.group(3).strip()
        self.first_date_of_operation = parse_date(matches.group(4))
        self.last_date_of_operation = parse_date(matches.group(5))
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

        self.hops = []

    def __str__(self):
        ret = CIFRecord.__str__(self) + "\n"
        counter = 0
        for hop in self.hops:
            counter = counter + 1
            ret = ret + "\t" + str(counter) + ". " + str(hop) + "\n"
        return ret

    def add_hop(self, hop):
        assert isinstance(hop, JourneyOrigin) or isinstance(hop, JourneyIntermediate) or isinstance(hop, JourneyDestination)
        self.hops.append(hop)

    # Given a datetime.date returns True or False according to whether the
    # journey runs on that date.
    def is_valid_on_date(self, d):
        if not self.first_date_of_operation <= d and d <= self.last_date_of_operation:
            return False, "%s not in range of date of operation %s - %s" % (str(d), str(self.first_date_of_operation), str(self.last_date_of_operation))
        if not self.operates_on_day_of_week[d.isoweekday()]:
            return False, "journey doesn't operate on a " + d.strftime('%A')

        assert self.school_term_time == " ", "fancy school term related journey not implemented"
        assert self.bank_holidays == " ", "fancy bank holiday related journey not implemented"

        return True, "OK"

    # Given a location (as a string short code), return the time this journey
    # stops there, or None if it only starts there, or doesn't stop there.
    def find_arrival_time_at_location(self, location):
        ret = None
        for hop in self.hops:
            if hop.location == location:
                # XXX performance: could return here rather than assert, if we checked for duplicate stops thoroughly elsewhere
                assert ret == None, "location %s appears twice in journey %s" % (location, self.unique_journey_identifier)
                if isinstance(hop, JourneyIntermediate):
                    # B is documented "both pick up and set down flag"
                    # T is undocumented, but seems to mean train (so let's assume pick up and set down XXX)
                    # Other values you'll need to not use this hop
                    assert hop.activity_flag in ['B', 'T'], "activity_flag %s in journey %s not supported" % (hop.activity_flag, self.unique_journey_identifier)
                if not isinstance(hop, JourneyOrigin):
                    ret = hop.published_arrival_time

        return ret

# Origin of journey route
class JourneyOrigin(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QO")

        matches = re.match('^QO(.{12})(\d{4})(.{3})(T[01])(F0|F1|  )$', line)
        if not matches:
            raise Exception("Journey origin line incorrectly formatted: " + line)

        self.location = matches.group(1).strip()
        self.published_departure_time = parse_time(matches.group(2))
        self.bay_number = matches.group(3).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(4)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(5)]
    
# Intermediate stop on journey
class JourneyIntermediate(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QI")

        # BPSN are only documented values for activity_flag, but in real files we've found TOD as well.
        matches = re.match('^QI(.{12})(\d{4})(\d{4})([BPSNTOD])(.{3})(T[01])(F0|F1|  )$', line)
        if not matches:
            raise Exception("Journey intermediate line incorrectly formatted: " + line)

        self.location = matches.group(1).strip()
        self.published_arrival_time = parse_time(matches.group(2))
        self.published_departure_time = parse_time(matches.group(3))
        self.activity_flag = matches.group(4)
        self.bay_number = matches.group(5).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(6)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(7)]

# Destination of journey route
class JourneyDestination(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QT")

        matches = re.match('^QT(.{12})(\d{4})(.{3})(T[01])(F0|F1|  )$', line)
        if not matches:
            raise Exception("Journey destination line incorrectly formatted: " + line)

        self.location = matches.group(1).strip()
        self.published_arrival_time = parse_time(matches.group(2))
        self.bay_number = matches.group(3).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(4)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(5)]

# Destination of journey route, stores also additional record in self.additional
class Location(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QL")

        matches = re.match('^QL([NDR])(.{12})(.{48})(.)([BSPRID])(.{8})$', line)
        if not matches:
            raise Exception("Location line incorrectly formatted: " + line)

        self.transaction_type = matches.group(1)
        self.location = matches.group(2).strip()
        self.full_location = matches.group(3).strip()
        self.gazetteer_code = matches.group(4)
        self.point_type = matches.group(5)
        self.national_gazetteer_id = matches.group(6)
        self.additional = None

    def __str__(self):
        ret = CIFRecord.__str__(self) + "\n"
        if self.add_additional: 
            ret = ret + "\t" + str(self.additional)
        return ret

    def add_additional(self, additional):
        assert isinstance(additional, LocationAdditional)
        self.additional = additional
        
# Additional information on journey route
class LocationAdditional(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QB")

        matches = re.match('^QB([NDR])(.{12})(.{8})(.{8})(.{24})(.{24})$', line)
        if not matches:
            raise Exception("Location additional line incorrectly formatted: " + line)

        self.transaction_type = matches.group(1)
        self.location = matches.group(2).strip()
        self.grid_reference_easting = matches.group(3).strip()
        self.grid_reference_northing = matches.group(4).strip()
        self.district_name = matches.group(5).strip()
        self.town_name = matches.group(6).strip()

        







