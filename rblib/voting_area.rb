# -*- encoding : utf-8 -*-
# voting_area.rb - voting area definitions.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
module MySociety

  module VotingArea
  
    # va_council_parent_types
    # Types which are local councils, such as districts, counties,
    # unitary authorities and boroughs. 
    def self.va_council_parent_types
      ['DIS', 'LBO', 'MTD', 'UTA', 'LGD', 'CTY', 'COI']
    end
    
    # va_council_child_types
    # Types which are wards or electoral divisions in councils. 
    def self.va_council_child_types
      ['DIW', 'LBW', 'MTW', 'UTE', 'UTW', 'LGE', 'CED', 'COP']
    end
    
  end
  
end
