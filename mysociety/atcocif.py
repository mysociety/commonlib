#
# atcocif.py:
# ATCO-CIF transport journey file loader.
#
# Copyright (c) 2008 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: atcocif.py,v 1.18 2009-02-20 13:49:57 matthew Exp $
#

# TODO:

# Check that journey unique id is correct
#
# Look at the transaction types, are they always nice? What do with 'D' ones?
#
# Test exceptional date ranges more thoroughly, give error if they nest at all
#
# Work round school terms and bank holidays for definite somehow
#   School terms are needed but not implemented - where is the data?
#        [rs] Simple answer is "no" - the week for the sample to be taken is
#        deliberately one which is in school and University term time.  The data can
#        only represent the services operating in that week, when you should assume
#        that Schoolday journeys operate, and NSch ones don't.  Any conclusions other
#        than for the sample week would be prone to inaccuracy as I have no way of
#        knowing whether filtering was put in place in some data sources to exclude
#        services and journeys which did not operate in the sample week.
#   Bank holidays are needed but not implemented - where is the data?
#        [rs] Bank Holidays are not generally handled within the data - and no
#        conclusions can be drawn about the availability of Bank Holiday services
#        from NPTDR data.  The remit is only to have a complete set of data for the
#        sample week.

# Test duplicate hop removal - how do we test logging in doctest?
#        >>> logging.basicConfig(level=logging.WARN)
#        >>> jh.add_hop(JourneyIntermediate('QI9100BCNSFLD 16531653T   T1  '))
#        removed duplicate stop/time QI9100BCNSFLD 16531653T   T1  

# Later:
# Test is_set_down, is_pick_up maybe a bit more
# Test if timing point indicator tells you if points are interpolated
# Train activity flags
# - they should have pick up only for some cases, Matthew says:
#    london-brum will be pick up only at watford
#    manchester-london will be pick up only at stockport
# - check what activity flags 'T', 'O', 'D' for trains definitively mean

"""Loads files in the ATCO-CIF file format, which is used in the UK to specify
public transport journeys for accessibility planning by the National Public
Transport Data Repository (NPTDR).

Specification is here: http://www.pti.org.uk/CIF/atco-cif-spec.pdf 

atcocif.py does a lightweight, low level parse of the file. It aims to be
tolerant of deviations from the specification only where those have been found
in the wild.

There are some helper functions, which interpret the ATCO-CIF file. For
example, is_valid_on_date tests whether a particular journey applies on a given
specific day (allowing for weekends, bank holidays, school holidays etc.)

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
    def __init__(self):
        self.journeys = []
        self.locations = []

    def __str__(self):
        ret = str(self.file_header) + "\n"
        for journey in self.journeys:
            ret = ret + str(journey) + "\n"
        for location in self.locations:
            ret = ret + str(location) + "\n"
        return ret

    def read(self, f):
        '''Loads an ATCO-CIF file from a file.

        >>> import tempfile
        >>> n = tempfile.NamedTemporaryFile()
        >>> n.write('ATCO-CIF0510      Buckinghamshire - COACH             ATCOPT20080126111426')
        >>> n.flush()
        >>> atco = ATCO()
        >>> atco.read(n.name)
        >>> n.close()
        '''

        return self.read_file_handle(open(f))

    def read_string(self, s):
        '''Loads an ATCO-CIF file from a string.

        >>> atco = ATCO()
        >>> atco.read_string('ATCO-CIF0510      Buckinghamshire - COACH             ATCOPT20080126111426')
        '''
        h = StringIO.StringIO(s)
        return self.read_file_handle(h)

    def read_file_handle(self, h):
        '''Loads an ATCO-CIF file from a file handle.'''
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
                current_item.add_date_running_exception(JourneyDateRunning(line))
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
            elif record_identity in [
                'QV', # Vehicle type record
                'QD'  # Route description record
            ]:
                logging.warning("Ignoring record type '" + record_identity + "'")
            else:
                raise Exception("Unknown record type '" + record_identity + "'")

    def index_by_short_codes(self):
        '''Make dictionaries so it is quick to look up all journeys visiting a
        particular location, and to get details about a location from its identifier.

        >>> atco = ATCO()
        >>> atco.read_string("""ATCO-CIF0510                       70 - RAIL        ATCORAIL20080124115909
        ... QSNGW    6B1820070521200712071111100  2B02P10452TRAIN           I
        ... QO9100MDNHEAD 0549URLT1  
        ... QI9100FURZEP  05530553T   T1  
        ... QI9100COOKHAM 05560556T   T1  
        ... QI9100BORNEND 06010605T   T1  
        ... QT9100MARLOW  0612   T1  
        ... QSNGW    6B1A20070521200712071111100  2B04P10456TRAIN           I
        ... QO9100MDNHEAD 0608URLT1  
        ... QI9100FURZEP  06120612T   T1  
        ... QI9100COOKHAM 00000000O   T1  
        ... QT9100BORNEND 0620   T1  
        ... QLN9100COOKHAM Cookham Rail Station                             RE0057284
        ... QBN9100COOKHAM 488690  185060                                                  
        ... """)
        >>> atco.index_by_short_codes()
        >>> journeys_visiting_cookham = atco.journeys_visiting_location["9100COOKHAM"]
        >>> [x.id for x in journeys_visiting_cookham]
        ['GW6B1A', 'GW6B18']
        >>> atco.location_details["9100COOKHAM"].long_description()
        'Cookham Rail Station'
        '''

        self.journeys_visiting_location = {}
        for journey in self.journeys:
            for hop in journey.hops:
                if hop.location not in self.journeys_visiting_location:
                    self.journeys_visiting_location[hop.location] = set()

                if journey in self.journeys_visiting_location[hop.location]:
                    if hop == journey.hops[0] and hop == journey.hops[-1]:
                        # if it's a simple loop, starting and ending at same point, then that's OK
                        logging.debug("journey " + journey.id + " loops")
                        pass
                    else:
                        assert "same location %s appears twice in one journey %s, and not at start/end" % (hop.location, journey.id)

                self.journeys_visiting_location[hop.location].add(journey)

        self.location_details = {}
        for location in self.locations:
            self.location_details[location.location] = location

#        self.nearby_locations = {}
#        for location in self.locations:
#            easting = self.location_details[location].additional.grid_reference_easting
#            northing = self.location_details[location].additional.grid_reference_northing
#            for other_location, data in self.location_details.items():
#            other_easting = data.additional.grid_reference_easting
#            other_northing = data.additional.grid_reference_northing
#            dist = math.sqrt(((easting-other_easting)**2) + ((northing-other_northing)**2))
#            if dist < 3200: # c. 2 miles
#                logging.debug("%s (%d,%d) is %d away from %s (%d,%d)" % (location, easting, northing, dist, target_location, target_easting, target_northing))
#                self.nearby_locations.setdefault(location, {}).setdefault(other_location, dist)

###########################################################
# Helper functions and classes

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
    if date_string == '99999999' or date_string == '        ':
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

class BoolWithReason:
    '''Behaves as a boolean, only stores an explanatory string as well.
    
    >>> bwr1 = BoolWithReason(False, "the frobnitz was klutzed")
    >>> bwr1 and "yes" or "no"
    'no'
    >>> bwr1.reason
    'the frobnitz was klutzed'
    >>> bwr1
    BoolWithReason(False, 'the frobnitz was klutzed')

    >>> bwr2 = BoolWithReason(True, "all was good")
    >>> bwr2 and "yes" or "no"
    'yes'
    >>> bwr2
    BoolWithReason(True, 'all was good')
    '''

    def __init__(self, value, reason):
        self.value = value
        self.reason = reason

    def __repr__(self):
        return "BoolWithReason(" + repr(self.value) + ", " + repr(self.reason) + ")"

    def __nonzero__(self):
        return self.value



###########################################################
# Base record class

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

###########################################################
# Journey record classes

class JourneyHeader(CIFRecord):
    '''Header of a journey record. It stores all associated records too, and so 
    represents the whole journey. 
    
    >>> jh = JourneyHeader('QSNGW    6B3920070521200712071111100  2B82P10553TRAIN           I')
    >>> jh.transaction_type # New/Delete/Revise
    'N'
    >>> jh.operator
    'GW'
    >>> jh.unique_journey_identifier
    '6B39'
    >>> jh.id
    'GW6B39'
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

    JourneyDateRunning records are stored in self.date_running_exceptions - see
    the JourneyDateRunning definition for examples.

    JourneyOrigin, JourneyIntermediate, JourneyDestination records are stored
    in self.hops - see add_hop below for examples.
    '''

    def __init__(self, line):
        CIFRecord.__init__(self, line, "QS")

        matches = re.match('^QS([NDR])(.{4})(.{6})(\d{8})(\d{8}| {8})([01]{7})([ SH])([ ABX])(.{4})(.{6})(.{8})(.{8})(.)$', line)
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

        # Operator code and journey identifier are unique together
        self.id = self.operator + self.unique_journey_identifier

        self.hops = []
        self.hop_lines = {}
        self.date_running_exceptions = []
        self.ignored = False

    def __str__(self):
        ret = CIFRecord.__str__(self) + "\n"
        counter = 0
        for hop in self.hops:
            counter = counter + 1
            ret = ret + "\t" + str(counter) + ". " + str(hop) + "\n"
        return ret

    def add_date_running_exception(self, exception):
        '''See JourneyDateRunning for documentation of this function.'''
        assert isinstance(exception, JourneyDateRunning)
        self.date_running_exceptions.append(exception)

    def ignore(self):
        '''Mark a journey to be ignored by future calculations to save time'''
        self.ignored = True

    def is_valid_on_date(self, d):
        '''Given a datetime.date returns a pair of True or False according to
        whether the journey runs on that date, and the reasoning.

        >>> jh = JourneyHeader('QSNGW    6B3920070521200712071111100  2B82P10553TRAIN           I')
        >>> jh.is_valid_on_date(datetime.date(2007, 5, 21))
        BoolWithReason(True, 'OK')
        >>> jh.is_valid_on_date(datetime.date(2007, 5, 20))
        BoolWithReason(False, '2007-05-20 not in range of date of operation 2007-05-21 - 2007-12-07')
        >>> jh.is_valid_on_date(datetime.date(2007, 5, 26))
        BoolWithReason(False, "journey doesn't operate on a Saturday")

        You can add exceptions to the date range, see JourneyDateRunning below for examples.
        '''

        if self.ignored:
            return BoolWithReason(False, 'journey being ignored')

        # XXX not clearly defined in spec how these nest, but hey, this naive implementation might do
        excepted_state = None
        for exception in self.date_running_exceptions:
            if exception.start_of_exceptional_period <= d and d <= exception.end_of_exceptional_period:
                excepted_state = exception.operation_code
        if excepted_state == False:
            return BoolWithReason(False, "%s not in range of exceptional date records" % (str(d)))
        if excepted_state == None:
            if not self.first_date_of_operation <= d and d <= self.last_date_of_operation:
                return BoolWithReason(False, "%s not in range of date of operation %s - %s" % (str(d), str(self.first_date_of_operation), str(self.last_date_of_operation)))

        # check runs on this day of week
        if not self.operates_on_day_of_week[d.isoweekday()]:
            return BoolWithReason(False, "journey doesn't operate on a " + d.strftime('%A'))

        # school terms
        # assert self.school_term_time == " ", "fancy school term related journey not implemented " + self.school_term_time

        # bank holidays
        # assert self.bank_holidays == " ", "fancy bank holiday related journey not implemented " + self.bank_holidays

        return BoolWithReason(True, "OK")

    def add_hop(self, hop):
        '''This associates the start, intermediate and final stops of a journey
        with the journey header.

        >>> jh = JourneyHeader('QSNCH   2933E20071008200712071111100  1H49P80092TRAIN           I')
        >>> jh.add_hop(JourneyOrigin('QO9100PRINRIS 16362  T1  '))
        >>> jh.add_hop(JourneyIntermediate('QI9100SUNDRTN 16401640T   T1  '))
        >>> jh.add_hop(JourneyIntermediate('QI9100HWYCOMB 16471647T3  T1  '))
        >>> jh.add_hop(JourneyIntermediate('QI9100BCNSFLD 16531653T   T1  '))
        >>> jh.add_hop(JourneyIntermediate('QI9100GERRDSX 16591659T   T1  '))
        >>> jh.add_hop(JourneyDestination('QT9100MARYLBN 17286  T1  '))

        There are then some other functions you can call.

        >>> jh.find_arrival_time_at_location('9100BCNSFLD')
        datetime.time(16, 53)
        >>> print jh.find_arrival_time_at_location('9100PRINRIS')
        None
        >>> print jh.find_arrival_time_at_location('somewhere else')
        None
        '''

        if hop.line in self.hop_lines:
            # if we go to the same stop at the same time again, ignore duplicate
            logging.warn("removed duplicate stop/time " + hop.line)
            return
        assert isinstance(hop, JourneyOrigin) or isinstance(hop, JourneyIntermediate) or isinstance(hop, JourneyDestination)
        self.hops.append(hop)
        self.hop_lines[hop.line] = True

    def find_arrival_time_at_location(self, location):
        ''' Given a location (as a string short code), return the time this journey
        stops there, or None if it only starts there, or doesn't stop there.
            
        See add_hop above for examples.
        '''
        ret = None
        for hop in self.hops:
            if hop.location == location:
                if hop.is_set_down():
                    ret = hop.published_arrival_time

        return ret

class JourneyDateRunning(CIFRecord):
    '''Optionally follows a JourneyHeader. The header itself has only one simple
    date range for when a journey runs. This record creates exceptions from
    that range for when the journey does or does not run. 

    >>> jh = JourneyHeader('QSNSUC   599B20070910204912311111100  X5        COACH           5')
    >>> jh.is_valid_on_date(datetime.date(2007,12,25)) # Christmas day
    BoolWithReason(True, 'OK')
    >>> jdr = JourneyDateRunning('QE20071225200712250')
    >>> (jdr.start_of_exceptional_period, jdr.end_of_exceptional_period)
    (datetime.date(2007, 12, 25), datetime.date(2007, 12, 25))
    >>> jdr.operation_code
    False
    >>> jh.add_date_running_exception(jdr)
    >>> jh.is_valid_on_date(datetime.date(2007,12,25)) # Christmas day
    BoolWithReason(False, '2007-12-25 not in range of exceptional date records')
    '''

    def __init__(self, line):
        CIFRecord.__init__(self, line, "QE")

        matches = re.match('^QE(\d{8})(\d{8})([01])$', line)
        if not matches:
            raise Exception("Journey origin line incorrectly formatted: " + line)

        self.start_of_exceptional_period = parse_date(matches.group(1))
        self.end_of_exceptional_period = parse_date(matches.group(2))
        self.operation_code = bool(int(matches.group(3)))

class JourneyOrigin(CIFRecord):
    '''Start of a journey route.

    >>> jo = JourneyOrigin('QO9100MDNHEAD 09375B T1  ')
    >>> jo.location
    '9100MDNHEAD'
    >>> jo.published_departure_time
    datetime.time(9, 37)
    >>> jo.bay_number
    '5B'
    >>> jo.timing_point_indicator
    True
    >>> print jo.fare_stage_indicator # '  ' isn't in the spec for this, but occurs in wild, so we return None for it
    None

    There are some additional functions compatible with those in JourneyIntermediate.
    >>> jo.is_set_down()
    False
    >>> jo.is_pick_up()
    True
    '''

    def __init__(self, line):
        CIFRecord.__init__(self, line, "QO")

        matches = re.match('^QO(.{12})(\d{4})(.{3})(T[01])(F0|F1|  ) ?$', line)
        if not matches:
            raise Exception("Journey origin line incorrectly formatted: " + line)

        self.location = matches.group(1).strip().upper()
        self.published_departure_time = parse_time(matches.group(2))
        self.bay_number = matches.group(3).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(4)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(5)]

    def is_set_down(self):
        return False

    def is_pick_up(self):
        return True
    
class JourneyIntermediate(CIFRecord):
    '''Intermediate stop on a journey.

    >>> ji = JourneyIntermediate('QI9100FURZEP  09410941T   T1  ')
    >>> ji.location
    '9100FURZEP'
    >>> ji.published_arrival_time
    datetime.time(9, 41)
    >>> ji.published_departure_time
    datetime.time(9, 41)
    >>> ji.activity_flag # T isn't a documented value, but seen in wild, see below
    'T'
    >>> ji.bay_number
    ''
    >>> ji.timing_point_indicator
    True
    >>> print ji.fare_stage_indicator # '  ' isn't in the spec for this, but occurs in wild, so we return None for it
    None

    These functions tell you if the vehicle lets passengers off or allows
    passengers on at the stop. They interpret the activity_flag, 
    >>> ji.is_set_down()
    True
    >>> ji.is_pick_up()
    True
    '''

    def __init__(self, line):
        CIFRecord.__init__(self, line, "QI")

        # BPSN are documented values for activity_flag in CIF file, other train ones are documented
        # in http://www.atoc.org/rsp/_downloads/RJIS/20040601.pdf
        matches = re.match('^QI(.{12})(\d{4})(\d{4})([BPSNACDORTUX-])(.{3})(T[01])(F0|F1|  )$', line)
        if not matches:
            raise Exception("Journey intermediate line incorrectly formatted: " + line)

        self.location = matches.group(1).strip().upper()
        self.published_arrival_time = parse_time(matches.group(2))
        self.published_departure_time = parse_time(matches.group(3))
        self.activity_flag = matches.group(4)
        self.bay_number = matches.group(5).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(6)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(7)]

        # We think O means no stop for trains, and all such entries have no time marked
        if self.activity_flag == 'O':
            assert self.published_arrival_time == datetime.time(0, 0, 0) and self.published_departure_time == datetime.time(0, 0, 0)
        # D is the same as S - Set Down only. Always has 0000 for departure time.
        # Let us assume departure time = arrival.
        if self.activity_flag == 'D':
            assert self.published_departure_time == datetime.time(0, 0, 0)
            assert self.published_arrival_time != datetime.time(0, 0, 0)
            self.published_departure_time = self.published_arrival_time
        # U appears to be the opposite, same as P (Pick Up only).
        if self.activity_flag == 'U':
            assert self.published_departure_time != datetime.time(0, 0, 0)
            assert self.published_arrival_time == datetime.time(0, 0, 0)
            self.published_arrival_time = self.published_departure_time

    # B - Both pick up and set down
    # P - Pick up only
    # S - Set down only
    # N - Neither pick up nor set down
    # A - stop/shunt to Allow other trains to pass
    # C - stop to Change trainmen
    # D - set Down only (train)
    # O - train stop for Other operating reasons (so same as N)
    # R - Request stop
    # T - both pick up and set down (Train)
    # U - pick Up only (train)
    # X - pass another train at Xing point on single line
    # - - stop to attach/detach vehicles
    def is_set_down(self):
        if self.activity_flag in ['B', 'S', 'T', 'D', 'R']:
            return True
        if self.activity_flag in ['N', 'P', 'O', 'U', 'A', 'C', 'X', '-']:
            return False
        assert False, "activity_flag %s not supported (location %s) " % (self.activity_flag, self.location)
    def is_pick_up(self):
        if self.activity_flag in ['B', 'P', 'T', 'U', 'R']:
            return True
        if self.activity_flag in ['N', 'S', 'O', 'D', 'A', 'C', 'X', '-']:
            return False
        assert False, "activity_flag %s not supported (location %s)" % (self.activity_flag, self.location)


class JourneyDestination(CIFRecord):
    '''End of a journey route.

    >>> jd = JourneyDestination('QT9100MARLOW  0959   T1  ')
    >>> jd.location
    '9100MARLOW'
    >>> jd.published_arrival_time
    datetime.time(9, 59)
    >>> jd.bay_number
    ''
    >>> jd.timing_point_indicator
    True
    >>> print jd.fare_stage_indicator # '  ' isn't in the spec for this, but occurs in wild, so we return None for it
    None

    There are some additional functions compatible with those in JourneyIntermediate.
    >>> jd.is_set_down()
    True
    >>> jd.is_pick_up()
    False
    '''

    def __init__(self, line):
        CIFRecord.__init__(self, line, "QT")

        matches = re.match('^QT(.{12})(\d{4})(.{3})(T[01])(F0|F1|  )$', line)
        if not matches:
            raise Exception("Journey destination line incorrectly formatted: " + line)

        self.location = matches.group(1).strip().upper()
        self.published_arrival_time = parse_time(matches.group(2))
        self.bay_number = matches.group(3).strip()
        self.timing_point_indicator = { 'T0' : False, 'T1' : True }[matches.group(4)]
        self.fare_stage_indicator = { 'F0' : False, 'F1' : True, '  ' : None }[matches.group(5)]

    def is_set_down(self):
        return True

    def is_pick_up(self):
        return False
###########################################################
# Location record classes
 
class Location(CIFRecord):
    '''Further details about a location. 

    >>> l = Location('QLN9100CHLFNAL Chalfont and Latimer Rail Station                RE0044056')
    >>> l.transaction_type
    'N'
    >>> l.location
    '9100CHLFNAL'
    >>> l.full_location 
    'Chalfont and Latimer Rail Station'
    >>> l.gazetteer_code 
    ' '
    >>> l.point_type
    'R'
    >>> l.national_gazetteer_id
    'E0044056'

    It stores associated additional records as well.
    >>> la = LocationAdditional('QBN9100CHLFNAL 499647  197573  Chiltern                                        ')
    >>> l.add_additional(la)
    >>> l.additional.grid_reference_easting
    499647
    
    There is a long description of the location, which includes useful fields
    from the additional record.
    >>> l.long_description()
    'Chalfont and Latimer Rail Station, Chiltern'
    '''

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
        assert additional.location == self.location
        self.additional = additional

    def long_description(self):
        ret = self.full_location
        if self.additional:
            if len(self.additional.town_name) > 0:
                ret += ", " + self.additional.town_name 
            if len(self.additional.district_name) > 0:
                ret += ", " + self.additional.district_name
        return ret
        
class LocationAdditional(CIFRecord):
    ''' Additional information on journey route, automatically attached to associated Location.

    >>> la = LocationAdditional('QBN9100CHLFNAL 499647  197573  Chiltern                                        ')
    >>> la.transaction_type
    'N'
    >>> la.location
    '9100CHLFNAL'
    >>> la.grid_reference_easting
    499647
    >>> la.grid_reference_northing
    197573
    >>> la.district_name
    'Chiltern'
    >>> la.town_name
    ''
    '''

    def __init__(self, line):
        CIFRecord.__init__(self, line, "QB")

        matches = re.match('^QB([NDR])(.{12})(.{8})(.{8})(.{24})(.{24})$', line)
        if not matches:
            raise Exception("Location additional line incorrectly formatted: " + line)

        self.transaction_type = matches.group(1)
        self.location = matches.group(2).strip()
        self.grid_reference_easting = int(matches.group(3).strip())
        self.grid_reference_northing = int(matches.group(4).strip())
        self.district_name = matches.group(5).strip()
        self.town_name = matches.group(6).strip()


###########################################################

# Run tests if this module is executed directly. Recommended you use nosetests
# with doctest enabled to run tests found in lots of modules.
if __name__ == "__main__":
    import doctest
    doctest.testmod()

