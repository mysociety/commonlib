# validate.rb:
# mySociety library of validation functions, such as valid email address.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: validate.rb,v 1.1 2007-08-31 17:56:02 francis Exp $

module MySociety
    module Validate

        def Validate.is_valid_email(addr)
            # This is derived from the grammar in RFC2822.
            # mailbox = local-part "@" domain
            # local-part = dot-string | quoted-string
            # dot-string = atom ("." atom)*
            # atom = atext+
            # atext = any character other than space, specials or controls
            # quoted-string = '"' (qtext|quoted-pair)* '"'
            # qtext = any character other than '"', '\', or CR
            # quoted-pair = "\" any character
            # domain = sub-domain ("." sub-domain)* | address-literal
            # sub-domain = [A-Za-z0-9][A-Za-z0-9-]*
            # XXX ignore address-literal because nobody uses those...

            specials = '()<>@,;:\\\\".\\[\\]'
            controls = '\\000-\\037\\177'
            highbit = '\\200-\\377'
            atext = "[^#{specials} #{controls}#{highbit}]"
            atom = "#{atext}+"
            dot_string = "#{atom}(\\s*\\.\\s*#{atom})*"
            qtext = "[^\"\\\\\\r\\n#{highbit}]"
            quoted_pair = '\\.'
            quoted_string = "\"(#{qtext}|#{quoted_pair})*\""
            local_part = "(#{dot_string}|#{quoted_string})"
            sub_domain = '[A-Za-z0-9][A-Za-z0-9-]*'
            domain = "#{sub_domain}(\\s*\\.\\s*#{sub_domain})*"

            is_valid_address_re = Regexp.new("^#{local_part}\\s*@\\s*#{domain}\$")

            return addr =~ is_valid_address_re
        end
    end
end


