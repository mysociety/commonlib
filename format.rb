# format.rb:
# mySociety library of formatting functions.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: format.rb,v 1.6 2007-12-24 17:30:02 francis Exp $

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

        # Returns text with obvious links made into HTML hrefs.
        # Taken originally from phplib/utility.php and from WordPress, tweaked somewhat.
        def Format.make_clickable(text, params = {})
            nofollow = params[:nofollow]
            contract = params[:contract]

            ret = ' ' + text + ' '
            ret = ret.gsub(/(https?):\/\/([^\s<>{}()]+[^\s.,<>{}()])/i, "<a href='\\1://\\2'" + (nofollow ? " rel='nofollow'" : "") + ">\\1://\\2</a>")
            ret = ret.gsub(/(\s)www\.([a-z0-9\-]+)((?:\.[a-z0-9\-\~]+)+)((?:\/[^ <>{}()\n\r]*[^., <>{}()\n\r])?)/i,
                        "\\1<a href='http://www.\\2\\3\\4'" + (nofollow ? " rel='nofollow'" : "") + ">www.\\2\\3\\4</a>")
            if contract
                ret = ret.gsub(/(<a href='[^']*'(?: rel='nofollow')?>)([^<]{40})[^<]{3,}<\/a>/, '\\1\\2...</a>')
            end
            ret = ret.gsub(/(\s)([a-z0-9\-_.]+)@([^,< \n\r]*[^.,< \n\r])/i, "\\1<a href=\"mailto:\\2@\\3\">\\2@\\3</a>")
            ret = ret.strip
            return ret
        end

        # Differs from the Rails view helper pluralize, by not including the
        # number in the case of the singular.
        def Format.fancy_pluralize(num, singular, plural)
            if num == 1
                return singular
            else
                return num.to_s + " " + plural
            end
        end
    end
end


