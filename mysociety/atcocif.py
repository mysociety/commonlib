#
# atcocif.py:
# ATCO-CIF transport journey file loader.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: atcocif.py,v 1.10 2009-02-04 17:41:40 francis Exp $
#

# TODO:
# Move adjacent_location_times etc. to another file
# Look at the transaction types, are they always nice?
# Allow for the interchange time at the end :) - currently we'll always arrive early by that time
# timetz - what about time zones!  http://docs.python.org/lib/datetime-datetime.html
#
# Journeys over midnight will be knackered, no idea how ATCO-CIF even stores them
#  - in particular, which day are journeys starting just after midnight stored for?
#  - see "XXX bah" below for hack that will do for now but NEEDS CHANGING
#
# Test exceptional date ranges
# Check circular journeys work fine
# School terms are needed but not implemented - where is the data?
# Bank holidays are needed but not implemented - where is the data?
# interchange times
# - find proper ones to use for TRAIN and BUS
# - what is an LFBUS?
# - there are other ones as well, e.g. 09 etc. probably right to default to bus, but check

# Later:
# Train activity flags
# - they should have pick up only for some cases, Matthew says:
#    london-brum will be pick up only at watford
#    manchester-london will be pick up only at stockport
# - check what activity_flag 'O' for trains definitively means
# - check what activity_flag 'D' for trains definitively means


"""
Loads files in the ATCO-CIF file format, which is used in the UK to specify
public transport journeys for accessibility planning by the National Public
Transport Data Repository (NPTDR).

Specification is here: http://www.pti.org.uk/CIF/atco-cif-spec.pdf 

atcocif.py does a lightweight, low level parse of the file. It aims to be
tolerant of deviations from the specification only where those have been found
in the wild.

There are some low level helper functions, which interpret the ATCO-CIF file.
For example, is_valid_on_date tests whether a particular journey applies on a
given specific day (allowing for weekends, bank holidays, school holidays etc.)

The simplest ATCO-CIF file is just a header, with no further records.
>>> atco = ATCO()
>>> atco.read_string('ATCO-CIF0510      Buckinghamshire - BUS               ATCOPT20080125165808')
>>> atco.file_header.file_originator
'Buckinghamshire - BUS'

"""

import os
import sys
import re
import datetime
import mx.DateTime
import logging
import StringIO

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

        return self.read_file_handle(open(f))

    # Load from a string
    def read_string(self, s):
        h = StringIO.StringIO(s)
        return self.read_file_handle(h)

    # Load from a file handle
    def read_file_handle(self, h):
        self.handle = h

        line = self.handle.readline().strip("\n\r")
        self.file_header = FileHeader(line)

        # Load in every record - each record is one line of the file
        current_item = None
        for line in self.handle.readlines():
            line = line.strip("\n\r")
            #logging.debug(line)
            record_identity = line[0:2]
            record = None

            # Journeys - store the clump of records relating to one journey 
            if record_identity == 'QS':
                current_item = JourneyHeader(line)
                self.journeys.append(current_item)
            elif record_identity == 'QE':
                assert isinstance(current_item, JourneyHeader)
                current_item.add_exception(JourneyException(line))
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

                if journey in self.journeys_visiting_location[hop.location]:
                    if hop == journey.hops[0] and hop == journey.hops[-1]:
                        # if it's a simple loop, starting and ending at same point, then that's OK
                        logging.debug("journey " + journey.unique_journey_identifier + " loops")
                        pass
                    else:
                        assert "same location %s appears twice in one journey %s, and not at start/end" % (hop.location, journey.unique_journey_identifier)

                self.journeys_visiting_location[hop.location].add(journey)

        self.location_details = {}
        for location in self.locations:
            self.location_details[location.location] = location

    # Look for journeys that cross midnight
    def find_journeys_crossing_midnight(self):
        for journey in self.journeys:
            previous_departure_time = datetime.time(0, 0, 0)
            for hop in journey.hops:
                if hop.is_pick_up():
                    if previous_departure_time > hop.published_departure_time:
                        print "journey " + journey.unique_journey_identifier + " spans midnight"
                    previous_departure_time = hop.published_departure_time
            

    # Adjacency function for use with Dijkstra's algorithm on earliest time to arrive somewhere.
    # Given a location (string short code) and a date/time, it finds every
    # other station you can get there on time by one direct train/bus. 
    def adjacent_location_times(self, target_location, target_arrival_datetime):
        # Check that there are journeys visiting this location
        logging.debug("adjacent_location_times target_location: " + target_location + " target_arrival_datetime: " + str(target_arrival_datetime))
        if target_location not in self.journeys_visiting_location:
            raise Exception, "No journeys known visiting target_location " + target_location

        # Adjacents is dictionary from location to time at that location, and
        # is the data structure we are going to return from this function.
        adjacents = {}
        # Go through every journey visiting the location
        for journey in self.journeys_visiting_location[target_location]:
            logging.debug("\tconsidering journey: " + journey.unique_journey_identifier)

            self._adjacent_location_times_for_journey(target_location, target_arrival_datetime, adjacents, journey)

        return adjacents

    def _adjacent_location_times_for_journey(self, target_location, target_arrival_datetime, adjacents, journey):
        # Check whether the journey runs on the relevant date
        # XXX assumes we don't do journeys over midnight
        (valid_on_date, reason) = journey.is_valid_on_date(target_arrival_datetime.date()) 
        if not valid_on_date:
            logging.debug("\t\tnot valid on date: " + reason)
        else:
            # Find out when it arrives at this stop
            arrival_time_at_target_location = journey.find_arrival_time_at_location(target_location)
            if arrival_time_at_target_location == None:
                # arrival_time_at_target_location could be None here for e.g. pick up only stops
                pass
            else:
                logging.debug("\t\tarrival time at target location: " + str(arrival_time_at_target_location))
                arrival_datetime_at_target_location = datetime.datetime.combine(target_arrival_datetime.date(), arrival_time_at_target_location)

                # Work out how long we need to allow to change at the stop
                # XXX here need to know if the stop is the last destination stop, as you don't need interchange time
                if journey.vehicle_type == 'TRAIN':
                    interchange_time_in_minutes = self.train_interchange_default
                else:
                    interchange_time_in_minutes = self.bus_interchange_default
                interchange_time = datetime.timedelta(minutes = interchange_time_in_minutes)
                
                # See whether if we want to use this journey to get to this
                # stop, we get there on time to change to the next journey.
                if arrival_datetime_at_target_location + interchange_time > target_arrival_datetime:
                    logging.debug("\t\twhich is too late with interchange time %s, so not using journey" % str(interchange_time))
                else:
                    logging.debug("\t\tadding stops")
                    self._adjacent_location_times_add_stops(target_location, target_arrival_datetime, adjacents, journey, arrival_datetime_at_target_location)

    def _adjacent_location_times_add_stops(self, target_location, target_arrival_datetime, adjacents, journey, arrival_datetime_at_target_location):
        # Now go through every earlier stop, and add it to the list of returnable nodes
        for hop in journey.hops:
            # We've arrived at the target location (check is_set_down here so looped
            # journeys, where we end on stop we started, work)
            if hop.is_set_down() and hop.location == target_location:
                break
            if hop.is_pick_up():
                departure_datetime = datetime.datetime.combine(target_arrival_datetime.date(), hop.published_departure_time)
                # if the time at this hop is later than at target, must be a midnight rollover, and really
                # this hop is on the the day before, so change to that
                # XXX bah this is rubbish as it won't have done the is right day check right
                if departure_datetime > arrival_datetime_at_target_location:
                    departure_datetime = datetime.datetime.combine(target_arrival_datetime.date() - datetime.timedelta(1), hop.published_departure_time)
                # Use this location if new, or if it is later departure time than any previous one the same we've found.
                if hop.location in adjacents:
                    curr_latest = adjacents[hop.location]
                    if departure_datetime > curr_latest:
                        adjacents[hop.location] = departure_datetime
                else:
                    adjacents[hop.location] = departure_datetime
            

###########################################################
# Helper functions

def parse_time(time_string):
    '''Converts a time string from an ATCO-CIF field into a Python time object.

    >>> parse_time('0549')
    datetime.time(5, 49)
    >>> parse_time('9999')
    Traceback (most recent call last):
        ...
    ValueError: hour must be in 0..23
    '''
    assert len(time_string) == 4
    return datetime.time(int(time_string[0:2]), int(time_string[2:4]), 0)

def parse_date(date_string):
    '''Converts a date string from an ATCO-CIF field into a Python date object.

    >>> parse_date('20080204')
    datetime.date(2008, 2, 4)
    >>> parse_date('99999999') # appears in some bus timetables e.g. ATCO_040_BUS.CIF in 2007 sample data
    datetime.date(9999, 12, 31)
    >>> parse_date('20083001')
    Traceback (most recent call last):
        ...
    ValueError: month must be in 1..12
    '''
    assert len(date_string) == 8
    if date_string == '99999999':
        date_string = '99991231'
    return datetime.date(
        int(date_string[0:4]), int(date_string[4:6]), int(date_string[6:8]),
    )

def parse_date_time(date_string, time_string):
    '''Converts a date and time string from an ATCO-CIF field into a Python
    combined date/time object. Unlike timetable times above, these full time
    stamps also contain seconds.

    >>> parse_date_time('20090204','155901')
    datetime.datetime(2009, 2, 4, 15, 59, 1)
    '''
    assert len(date_string) == 8
    assert len(time_string) == 6
    return datetime.datetime(
        int(date_string[0:4]), int(date_string[4:6]), int(date_string[6:8]),
        int(time_string[0:2]), int(time_string[2:4]), int(time_string[4:6]), 0
    )

###########################################################
# Individual record classes

class CIFRecord:
    """Base class of individual records from the ATCO-CIF file. Stores the line of
    text the the derived classes parser into members of the class. 

    Each line has a two character identifier at its start, which is checked against
    the expected identifier passed in.

    >>> c = CIFRecord("QT9100BORNEND 0620   T1", "QT")
    >>> c = CIFRecord("QT9100BORNEND 0620   T1", "QX")
    Traceback (most recent call last):
        ...
    Exception: CIF identifier 'QT' when expected 'QX'
    """

    def __init__(self, line, record_identity):
        assert len(record_identity) == 2
        self.line = line
        assert len(line) >= 2
        self.record_identity = line[0:2]
        if self.record_identity != record_identity:
            raise Exception, "CIF identifier '" + self.record_identity + "' when expected '" + record_identity + "'"

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
    """ATC-CIF files begin with a special header that cannot be nonsense.

    >>> atco = ATCO()
    >>> atco.read_string(u'ATnonsense')
    Traceback (most recent call last):
        ...
    Exception: ATCO-CIF header line incorrectly formatted: ATnonsense

    Here is an example of a valid header. The space padded strings within the header
    are trimmed, and the production date/time is parsed out as a Python object.

    >>> atco.read_string(u'ATCO-CIF0510                       70 - RAIL        ATCORAIL20080124115909')
    >>> atco.file_header.version_major, atco.file_header.version_minor
    (5, 10)
    >>> atco.file_header.file_originator
    u'70 - RAIL'
    >>> atco.file_header.source_product
    u'ATCORAIL'
    >>> atco.file_header.production_datetime
    datetime.datetime(2008, 1, 24, 11, 59, 9)
    """

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

class JourneyHeader(CIFRecord):
    '''Header of a journey record, stores all associated records too (in self.hops)

    >>> jh = JourneyHeader('QSNGW    6B3920070521200712071111100  2B82P10553TRAIN           I')
    >>> jh.transaction_type # New/Delete/Revise
    'N'
    >>> jh.operator
    'GW'
    >>> jh.unique_journey_identifier
    '6B39'
    >>> jh.first_date_of_operation
    datetime.date(2007, 5, 21)
    >>> jh.last_date_of_operation
    datetime.date(2007, 12, 7)
    >>> jh.operates_on_day_of_week
    [False, True, True, True, True, True, False, False]
    >>> jh.school_term_time
    ' '
    >>> jh.bank_holidays
    ' '
    >>> jh.route_number
    '2B82'
    >>> jh.running_board
    'P10553'
    >>> jh.vehicle_type
    'TRAIN'
    >>> jh.registration_number
    ''
    >>> jh.route_direction
    'I'
    '''

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
        self.operates_on_day_of_week[0] = bool(int(day_of_week_group[6])) # fill in Sunday at both ends for convenience
        self.school_term_time = matches.group(7)
        self.bank_holidays = matches.group(8)
        self.route_number = matches.group(9)
        self.running_board = matches.group(10).strip()
        self.vehicle_type = matches.group(11).strip()
        self.registration_number = matches.group(12).strip()
        self.route_direction = matches.group(13)

        self.hops = []
        self.hop_lines = {}
        self.exceptions = []

    def __str__(self):
        ret = CIFRecord.__str__(self) + "\n"
        counter = 0
        for hop in self.hops:
            counter = counter + 1
            ret = ret + "\t" + str(counter) + ". " + str(hop) + "\n"
        return ret

    def add_hop(self, hop):
        if hop.line in self.hop_lines:
            # if we go to the same stop at the same time again, ignore duplicate
            logging.warn("removed duplicate stop/time " + hop.line)
            return
        assert isinstance(hop, JourneyOrigin) or isinstance(hop, JourneyIntermediate) or isinstance(hop, JourneyDestination)
        self.hops.append(hop)
        self.hop_lines[hop.line] = True

    def add_exception(self, exception):
        assert isinstance(exception, JourneyException)
        self.exceptions.append(exception)

    # Given a datetime.date returns True or False according to whether the
    # journey runs on that date.
    def is_valid_on_date(self, d):
        # check date ranges, and exceptions to them
        # XXX not clearly defined in spec how these nest, but hey, this naive implementation might do
        excepted_state = None
        for exception in self.exceptions:
            if exception.start_of_exceptional_period <= d and d <= exception.end_of_exceptional_period:
                excepted_state = exception.operation_code
        if excepted_state == False:
            return False, "%s not in range of exceptional date records" % (str(d))
        if excepted_state == None:
            if not self.first_date_of_operation <= d and d <= self.last_date_of_operation:
                return False, "%s not in range of date of operation %s - %s" % (str(d), str(self.first_date_of_operation), str(self.last_date_of_operation))

        # check runs on this day of week
        if not self.operates_on_day_of_week[d.isoweekday()]:
            return False, "journey doesn't operate on a " + d.strftime('%A')

        # school terms
        # assert self.school_term_time == " ", "fancy school term related journey not implemented " + self.school_term_time

        # bank holidays
        # assert self.bank_holidays == " ", "fancy bank holiday related journey not implemented " + self.bank_holidays

        return True, "OK"

    # Given a location (as a string short code), return the time this journey
    # stops there, or None if it only starts there, or doesn't stop there.
    def find_arrival_time_at_location(self, location):
        ret = None
        for hop in self.hops:
            if hop.location == location:
                if hop.is_set_down():
                    ret = hop.published_arrival_time

        return ret

# Exceptions to dates of journey
class JourneyException(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QE")

        matches = re.match('^QE(\d{8})(\d{8})([01])$', line)
        if not matches:
            raise Exception("Journey origin line incorrectly formatted: " + line)

        self.start_of_exceptional_period = parse_date(matches.group(1))
        self.end_of_exceptional_period = parse_date(matches.group(2))
        self.operation_code = bool(int(matches.group(3)))

# Origin of journey route
class JourneyOrigin(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QO")

        matches = re.match('^QO(.{12})(\d{4})(.{3})(T[01])(F0|F1|  ) ?$', line)
        if not matches:
            raise Exception("Journey origin line incorrectly formatted: " + line)

        self.location = matches.group(1).strip()
        self.published_departure_time = parse_time(matches.group(2))
        self.bay_number = matches.group(3).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(4)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(5)]

    def is_set_down(self):
        return False

    def is_pick_up(self):
        return True
    
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

        # We think O means no stop for trains, and all such entries have no time marked
        if self.activity_flag == 'O':
            assert self.published_arrival_time == datetime.time(0, 0, 0) and self.published_departure_time == datetime.time(0, 0, 0)
        # D is another undocumented train pickup/putdown flag, always
        # associated with 0000 for arrival time. We think it means they only
        # know the departure time, and not arrival. Let us depressingly assume
        # they are the same.
        if self.activity_flag == 'D':
            assert self.published_departure_time == datetime.time(0, 0, 0)
            assert self.published_arrival_time != datetime.time(0, 0, 0)
            self.published_departure_time = self.published_arrival_time

    # B - both pick up and set down
    # P - pick up only
    # S - set down only
    # N - neither pick u pnor set down
    # T - undocumented, but seems to mean train (so let's assume pick up and set down XXX)
    # D - another train special, see above where we hack the departure time for it
    # O - we think means a train stop where train doesn't stop XXX
    def is_set_down(self):
        if self.activity_flag in ['B', 'S', 'T', 'D']:
            return True
        if self.activity_flag in ['N', 'P', 'O']:
            return False
        assert False, "activity_flag %s not supported (location %s) " % (self.activity_flag, self.location)
    def is_pick_up(self):
        if self.activity_flag in ['B', 'P', 'T', 'D']:
            return True
        if self.activity_flag in ['N', 'S', 'O']:
            return False
        assert False, "activity_flag %s not supported (location %s)" % (self.activity_flag, self.location)


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

    def is_set_down(self):
        return True

    def is_pick_up(self):
        return False
 
# Destination of journey route, stores also additional record in self.additional
class Location(CIFRecord):
    def __init__(self, line):
        CIFRecord.__init__(self, line, "QL")

        matches = re.match('^QL([NDR])(.{12})(.{48})(.)([BSPRID ])(.{8})$', line)
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
        if self.additional: 
            ret = ret + "\t" + str(self.additional)
        return ret

    def add_additional(self, additional):
        assert isinstance(additional, LocationAdditional)
        self.additional = additional

    def long_description(self):
        ret = self.full_location
        if self.additional:
            if len(self.additional.town_name) > 0:
                ret += ", " + self.additional.town_name 
            if len(self.additional.district_name) > 0:
                ret += ", " + self.additional.district_name
        return ret
        
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

        







