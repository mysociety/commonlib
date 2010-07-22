# mapit.rb:
# Client interface for MaPit
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# WWW: http://www.mysociety.org
#
# $Id: rabxresttorb.pl,v 1.3 2010-06-08 15:00:04 louise Exp $
#

require 'config'
require 'rabx'

module MySociety
  
  module MaPit
  
    def MaPit.do_call_rest_rabx(*params)
      base_url = MySociety::Config.get("MAPIT_URL")
      return MySociety::RABX.call_rest_rabx(base_url, params)
    end

    BAD_POSTCODE = 2001        #    String is not in the correct format for a postcode. 
    POSTCODE_NOT_FOUND = 2002        #    The postcode was not found in the database. 
    AREA_NOT_FOUND = 2003        #    The area ID refers to a non-existent area. 

    def MaPit.get_voting_areas(postcode, generation = nil)

      #* MaPit.get_voting_areas POSTCODE [GENERATION]
      #
      #  Return voting area IDs for POSTCODE. If GENERATION is given, use that,
      #  otherwise use the current generation.

      result = MaPit.do_call_rest_rabx('MaPit.get_voting_areas', postcode, generation)
      return result
    end

    def MaPit.get_voting_area_info(area)

      #* MaPit.get_voting_area_info AREA
      #
      #  Return information about the given voting area. Return value is a
      #  reference to a hash containing elements,
      #
      #  * type
      #
      #    OS-style 3-letter type code, e.g. "CED" for county electoral division;
      #
      #  * name
      #
      #    name of voting area;
      #
      #  * parent_area_id
      #
      #    (if present) the ID of the enclosing area.
      #
      #  * area_id
      #
      #    the ID of the area itself
      #
      #  * generation_low, generation_high, generation
      #
      #    the range of generations of the area database for which this area is to
      #    be used and the current active generation.

      result = MaPit.do_call_rest_rabx('MaPit.get_voting_area_info', area)
      return result
    end

    def MaPit.get_voting_areas_info(ary)

      #* MaPit.get_voting_areas_info ARY
      #
      #  As get_voting_area_info, only takes an array of ids, and returns an array
      #  of hashes.

      result = MaPit.do_call_rest_rabx('MaPit.get_voting_areas_info', ary)
      return result
    end

    def MaPit.get_voting_area_by_name(name, type = nil, min_generation = nil)

      #* MaPit.get_voting_area_by_name NAME [TYPE] [MIN_GENERATION]
      #
      #  Given NAME, return the area IDs (and other info) that begin with that
      #  name, or undef if none found. If TYPE is specified (scalar or array ref),
      #  only return areas of those type(s). If MIN_GENERATION is given, return
      #  all areas since then.

      result = MaPit.do_call_rest_rabx('MaPit.get_voting_area_by_name', name, type, min_generation)
      return result
    end

    def MaPit.get_voting_areas_by_location(coordinate, method, types = nil, generation = nil)

      #* MaPit.get_voting_areas_by_location COORDINATE METHOD [TYPE(S)] [GENERATION]
      #
      #  Returns a hash of voting areas and types which the given COORDINATE
      #  (either easting and northing, or latitude and longitude) is in. This only
      #  works for areas which have geometry information associated with them.
      #  i.e. that get_voting_area_geometry will return data for.
      #
      #  METHOD can be 'box' to just use a bounding box test, or 'polygon' to also
      #  do an exact point in polygon test. 'box' is quicker, but will return too
      #  many results. 'polygon' should return at most one result for a type.
      #
      #  If TYPE is present, restricts to areas of that type, such as WMC for
      #  Westminster Constituencies only. If not specified, note that doing the
      #  EUR/SPE/WAE calculation can be very slow (order of 10-20 seconds on live
      #  site). XXX Can this be improved by short-circuiting (only one EUR result
      #  returned, etc.)?

      result = MaPit.do_call_rest_rabx('MaPit.get_voting_areas_by_location', coordinate, method, types, generation)
      return result
    end

    def MaPit.get_areas_by_type(type, min_generation = nil)

      #* MaPit.get_areas_by_type TYPE [MIN_GENERATION]
      #
      #  Returns an array of ids of all the voting areas of type TYPE. TYPE is the
      #  three letter code such as WMC. By default only gets active areas in
      #  current generation, if MIN_GENERATION is provided then returns from that
      #  generation on, or if -1 then gets all areas for all generations.

      result = MaPit.do_call_rest_rabx('MaPit.get_areas_by_type', type, min_generation)
      return result
    end

    def MaPit.get_example_postcode(id)

      #* MaPit.get_example_postcode ID
      #
      #  Given an area ID, returns one random postcode that maps to it.

      result = MaPit.do_call_rest_rabx('MaPit.get_example_postcode', id)
      return result
    end

    def MaPit.get_voting_area_children(id)

      #* MaPit.get_voting_area_children ID
      #
      #  Return array of ids of areas whose parent areas are ID. Only returns
      #  those which are in generation. XXX expand this later with an ALL optional
      #  parameter as get_areas_by_type

      result = MaPit.do_call_rest_rabx('MaPit.get_voting_area_children', id)
      return result
    end

    def MaPit.get_location(postcode, partial = nil)

      #* MaPit.get_location POSTCODE [PARTIAL]
      #
      #  Return the location of the given POSTCODE. The return value is a
      #  reference to a hash containing elements. If PARTIAL is present set to 1,
      #  will use only the first part of the postcode, and generate the mean
      #  coordinate. If PARTIAL is set POSTCODE can optionally be just the first
      #  part of the postcode.
      #
      #  * coordsyst
      #
      #  * easting
      #
      #  * northing
      #
      #    Coordinates of the point in a UTM coordinate system. The coordinate
      #    system is identified by the coordsyst element, which is "G" for OSGB
      #    (the Ordnance Survey "National Grid" for Great Britain) or "I" for the
      #    Irish Grid (used in the island of Ireland).
      #
      #  * wgs84_lat
      #
      #  * wgs84_lon
      #
      #    Latitude and longitude in the WGS84 coordinate system, expressed as
      #    decimal degrees, north- and east-positive.

      result = MaPit.do_call_rest_rabx('MaPit.get_location', postcode, partial)
      return result
    end

  end
end
