# debug_helpers.rb:
# mySociety library of debugging functions.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: debug_helpers.rb,v 1.1 2009-09-15 17:45:50 francis Exp $

# XXX there are some tests in foi/spec/lib/format_spec.rb
# Really these should be in this rblib directory, and somehow made to run from
# the foi app.

module MySociety
    module DebugHelpers

        def self.allocated_string_size
            s = 0
            ObjectSpace.each_object(String) {|x| s = s + x.size }
            return s
        end

        def self.allocated_string_size_in_mb
            (allocated_string_size.to_f / 1024 / 1024)
        end

        def self.allocated_string_size_around_gc
            before = self.allocated_string_size_in_mb
            GC.start
            after = self.allocated_string_size_in_mb
            return "Before: " + before.to_s + " MB  GC  After: " + after.to_s + " MB"
        end

    end
end

