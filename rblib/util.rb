# util.rb:
# mySociety library of general utility functions
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
#
require 'openssl'
module MySociety

  module Util
    # Makes a random token, suitable for using in URLs e.g confirmation messages.
    def self.generate_token
      bits = 12 * 8
      # Make range from value to double value, so number of digits in base 36
      # encoding is quite long always.
      rand_num = rand(max = 2**(bits+1)) + 2**bits
      rand_num.to_s(base=36)
    end

    # breaks a list of items into a hash keyed by first letter of their descriptor block
    # If no block supplied, tries each item's name, or else uses to_s
    def self.by_letter(items, force_case=:none)
      items_by_first = Hash.new { |hash, key| hash[key] = [] }
      items.each do |item|
        if block_given?
          descriptor = yield item
        elsif item.respond_to?('name')
          descriptor = item.name
        else
          descriptor = item.to_s
        end
        # Strip non-alphanumeric characters
        clean_descriptor = descriptor.gsub(/^[^a-zA-Z0-9]+/, '')

        # If there are no non-alphanumeric characters, use the original descriptor
        if clean_descriptor.empty?
          clean_descriptor = descriptor
        end
        first = clean_descriptor[0].chr
        case force_case
          when :upcase
            first.upcase!
          when :downcase
            first.downcase!
        end
        items_by_first[first] << item
      end
      items_by_first
    end

  end

end
