# format.rb:
# mySociety library of formatting functions.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: format.rb,v 1.24 2009-10-04 21:42:07 francis Exp $

# the tests in tests/format.rb should somehow made to run from
# the foi app.
require 'cgi'
require 'unicode'
require 'unidecode'

module MySociety
    module Format

        # Word wrap the body of a text email.
        # ... either taking a blank line as a paragraph seperator.
        def Format.wrap_email_body_by_paragraphs(body)
            return Format._wrap_email_internal(body, 67, "     ", "\n\n")
        end
        # ... or wrapping each line separately.
        def Format.wrap_email_body_by_lines(body)
            return Format._wrap_email_internal(body, 67, "     ", "\n")
        end
        # Internal function for above
        def Format._wrap_email_internal(body, line_width, indent, paragraph_split)
            body = body.gsub(/\r\n/, "\n") # forms post with \r\n by default
            paras = body.split(paragraph_split)

            result = ''
            for para in paras
                para.gsub!(/\s+/, ' ')
                # the [^\s]{#{line_width+1},} part is to make sure we don't
                # break URLs etc. that are longer than a line, by including
                # anything non whitespace longer than a line whole.
                para.gsub!(/(.{1,#{line_width}}|[^\s]{#{line_width+1},})(\s+|$)/, "#{indent}\\1\n")
                para.strip!
                result = result + indent + para + paragraph_split
            end
            return result
        end

        # Returns text with obvious links made into HTML hrefs.
        # Taken originally from phplib/utility.php and from WordPress, tweaked somewhat.
        def Format.make_clickable(text, params = {})
            nofollow = params[:nofollow]
            contract = params[:contract]
            ret = ' ' + text + ' '

            # Special case as we get already HTML encoded < and > at end and start
            # of URLs often, when used to bracket them
            # e.g. http://www.whatdotheyknow.com/request/records_of_tenancy_property#incoming-212
            ret = ret.gsub(/&lt;/, " LTCODE ")
            ret = ret.gsub(/&gt;/, " GTCODE ")

            # Sometimes get angle bracketed URLs with newlines in the middle of them.
            # http://www.whatdotheyknow.com/request/advice_sought_from_information_c#incoming-24711
            ret = ret.gsub(/( LTCODE http[\S\r\n]*? GTCODE )/) { |m| m.gsub(/[\n\r]/, "") }

            ret = ret.gsub(/(https?):\/\/([^\s<>{}()]+[^\s.,<>{}()])/i, "<a href='\\1://\\2'" + (nofollow ? " rel='nofollow'" : "") + ">\\1://\\2</a>")
            ret = ret.gsub(/(\s)www\.([a-z0-9\-]+)((?:\.[a-z0-9\-\~]+)+)((?:\/[^ <>{}()\n\r]*[^., <>{}()\n\r])?)/i,
                        "\\1<a href='http://www.\\2\\3\\4'" + (nofollow ? " rel='nofollow'" : "") + ">www.\\2\\3\\4</a>")
            if contract
                ret = ret.gsub(/(<a href='[^']*'(?: rel='nofollow')?>)([^<]{40})[^<]{3,}<\/a>/, '\\1\\2...</a>')
            end
            ret = ret.gsub(/(\s)([a-z0-9\-_.]+)@([^,< \n\r]*[^.,< \n\r])/i, "\\1<a href=\"mailto:\\2@\\3\">\\2@\\3</a>")

            # Put back the codes for < and >
            ret = ret.gsub(" LTCODE ", "&lt;")
            ret = ret.gsub(" GTCODE ", "&gt;")

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
        def Format.simplify_url_part(text, default_name, max_len = nil)
            text = text.downcase # this also clones the string, if we use downcase! we modify the original
            text = Unicode.normalize_KD(text)
            text = Unidecoder.decode(text).downcase

            text.gsub!(/(\s|-|_)/, "_")
            text.gsub!(/[^a-z0-9_]/, "")
            text.gsub!(/_+/, "_")
            text.gsub!(/^_*/, "")
            text.gsub!(/_*$/, "")

            # If required, trim down to size
            if not max_len.nil?
                if text.size > max_len
                    text = text[0..(max_len-1)]
                end
                # removing trailing _
                text.gsub!(/_*$/, "")
            end
            # Don't allow short (zero length!), or all numeric (clashes with identifiers)
            if text.size < 1 || text.match(/^[0-9]+$/)
                text = default_name # just do "user_1", "user_2" etc.
            end

            text
        end

        # Really, why aren't these in Ruby? (and no, capitalize is no good, as it
        # lowercases the whole of the rest of the string, yeuch)
        def Format.lcfirst(text)
            text[0,1].downcase + text[1,text.size]
        end
        
        def Format.ucfirst(text)
            text[0,1].upcase + text[1,text.size]
        end

    end
end


