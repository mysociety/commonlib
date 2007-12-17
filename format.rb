# format.rb:
# mySociety library of formatting functions.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: format.rb,v 1.4 2007-12-17 03:31:34 francis Exp $

module MySociety
    module Format

        # Word wrap the body of a text email.
        def Format.wrap_email_body(body, line_width = 69, indent = "     ")
            body = body.gsub(/\r\n/, "\n") # forms post with \r\n by default
            paras = body.split(/\n\n/)

            result = ''
            for para in paras
                para.gsub!(/\s+/, ' ')
                para.gsub!(/(.{1,#{line_width}})(\s+|$)/, "#{indent}\\1\n")
                para.strip!
                result = result + indent + para + "\n\n"
            end
            return result
        end
    end
end


