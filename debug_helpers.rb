# debug_helpers.rb:
# mySociety library of debugging functions.
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: debug_helpers.rb,v 1.2 2009-09-17 10:00:27 francis Exp $

# XXX there are some tests in foi/spec/lib/format_spec.rb
# Really these should be in this rblib directory, and somehow made to run from
# the foi app.

module MySociety
    module DebugHelpers

        # Show amount of memory used for accessible Ruby string objects.
        # It can be useful to add log statements to help work out peak memory
        # use in the middle of operations. e.g.
        #   STDOUT.puts 'xxxxxx '+ MySociety::DebugHelpers::allocated_string_size_around_gc
        # It is important to keep peak memory use low, as Ruby never returns
        # memory to the OS until the process expires.
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

