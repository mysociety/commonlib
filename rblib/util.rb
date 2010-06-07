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
    def Util.generate_token
      bits = 12 * 8
      # Make range from value to double value, so number of digits in base 36
      # encoding is quite long always.
      rand_num = rand(max = 2**(bits+1)) + 2**bits
      rand_num.to_s(base=36)
    end
    
  end

end
