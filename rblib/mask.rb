# -*- encoding : utf-8 -*-
# mask.rb - text masking functions
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
require 'validate' 

module MySociety

  module Mask

    def self.mask_emails(text)
      text.gsub!(MySociety::Validate.email_find_regexp, '[email address]')
      text
    end

    def self.mask_mobiles(text)
      # Mobile phone numbers
      text.gsub!(/(Mobile|Mob)([\s\/]*(Fax|Tel))*\s*:?[\s\d]*\d/, "[mobile number]")
      text
    end
        
  end

end
