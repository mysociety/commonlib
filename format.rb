# format.rb:
# mySociety library of formatting functions.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: format.rb,v 1.13 2008-04-14 08:50:13 francis Exp $

module MySociety
    module Format

        # Word wrap the body of a text email.
        def Format.wrap_email_body(body, line_width = 69, indent = "     ")
            body = body.gsub(/\r\n/, "\n") # forms post with \r\n by default
            paras = body.split(/\n\n/)

            result = ''
            for para in paras
                para.gsub!(/\s+/, ' ')
                # the [^\s]* and \\2 parts are to make sure we don't break up long URLs etc.
                para.gsub!(/(.{1,#{line_width}})(?:\s+|([^\s]*)$)/, "#{indent}\\1\\2\n")
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

        # Simplify bracketed URLs like: www.liverpool.gov.uk <http://www.liverpool.gov.uk> 
        # (so that the URL appears only once, and so that the escaping of the < > doesn't
        # get &gt; contaminated into the linked URL)
        def Format.simplify_angle_bracketed_urls(text)
            ret = ' ' + text + ' '
            #ret = ret.gsub(/(www\.[^\s<>{}()])\s+\<(https?):\/\//i, "\\1")
            ret = ret.gsub(/(www\.[^\s<>{}()]+)\s+<http:\/\/\1>/i, "\\1")
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

        # Simplified a name to something usable in a URL
        def Format.simplify_url_part(text, max_len = nil)
            text = text.downcase # this also clones the string, if we use downcase! we modify the original
            text.gsub!(/(\s|-|_)/, "_")
            text.gsub!(/[^a-z0-9_]/, "")
            text.gsub!(/_+/, "_")

            # If required, trim down to size
            if not max_len.nil?
                if text.size > max_len
                    text = text[0..(max_len-1)]
                end
                # removing trailing _
                text.gsub!(/_*$/, "")
            end
            if text.size < 1
                text = 'user' # just do user1, user2 etc.
            end

            text
        end

    end
end


