# -*- coding: utf-8 -*-
# validate.rb:
# mySociety library of validation functions, such as valid email address.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: validate.rb,v 1.8 2009-10-19 23:52:40 francis Exp $

module MySociety
    module Validate

        if RUBY_VERSION.to_f >= 1.9
            @@lowercase_re = /[[:lower:]]/
        else
            # Ruby 1.8 doesn't support POSIX bracket expressions, so
            # these are all the Unicode characters that have the
            # Unicode category Ll (i.e. lowercase letters). This
            # can be removed when we no longer support Ruby 1.8.
            @@lowercase_re = %r{[a-zªµºß-öø-ÿāăąćĉċčďđēĕėęěĝğġģĥħĩī]|
                [ĭįıĳĵķ-ĸĺļľŀłńņň-ŉŋōŏőœŕŗřśŝşšţťŧũūŭůűųŵŷźżž-ƀƃƅƈƌ-ƍƒƕƙ-ƛƞơ]|
                [ƣƥƨƪ-ƫƭưƴƶƹ-ƺƽ-ƿǆǉǌǎǐǒǔǖǘǚǜ-ǝǟǡǣǥǧǩǫǭǯ-ǰǳǵǹǻǽǿȁȃȅȇȉȋȍȏȑȓȕ]|
                [ȗșțȝȟȡȣȥȧȩȫȭȯȱȳ-ȹȼȿ-ɀɂɇɉɋɍɏ-ʓʕ-ʯͱͳͷͻ-ͽΐά-ώϐ-ϑϕ-ϗϙϛϝϟϡϣϥϧϩϫϭ]|
                [ϯ-ϳϵϸϻ-ϼа-џѡѣѥѧѩѫѭѯѱѳѵѷѹѻѽѿҁҋҍҏґғҕҗҙқҝҟҡңҥҧҩҫҭүұҳҵҷҹһҽҿӂӄӆӈӊӌ]|
                [ӎ-ӏӑӓӕӗәӛӝӟӡӣӥӧөӫӭӯӱӳӵӷӹӻӽӿԁԃԅԇԉԋԍԏԑԓԕԗԙԛԝԟԡԣԥա-ևᴀ-ᴫ]|
                [ᵢ-ᵷᵹ-ᶚḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩ]|
                [ṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕ-ẝẟạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợ]|
                [ụủứừửữựỳỵỷỹỻỽỿ-ἇἐ-ἕἠ-ἧἰ-ἷὀ-ὅὐ-ὗὠ-ὧὰ-ώᾀ-ᾇᾐ-ᾗᾠ-ᾧᾰ-ᾴᾶ-ᾷιῂ-ῄῆ-ῇ]|
                [ῐ-ΐῖ-ῗῠ-ῧῲ-ῴῶ-ῷℊℎ-ℏℓℯℴℹℼ-ℽⅆ-ⅉⅎↄⰰ-ⱞⱡⱥ-ⱦⱨⱪⱬⱱⱳ-ⱴⱶ-ⱼⲁⲃⲅⲇⲉⲋⲍⲏⲑⲓⲕ]|
                [ⲗⲙⲛⲝⲟⲡⲣⲥⲧⲩⲫⲭⲯⲱⲳⲵⲷⲹⲻⲽⲿⳁⳃⳅⳇⳉⳋⳍⳏⳑⳓⳕⳗⳙⳛⳝⳟⳡⳣ-ⳤⳬⳮⴀ-ⴥꙁꙃꙅꙇꙉꙋꙍꙏꙑꙓꙕꙗꙙ]|
                [ꙛꙝꙟꙣꙥꙧꙩꙫꙭꚁꚃꚅꚇꚉꚋꚍꚏꚑꚓꚕꚗꜣꜥꜧꜩꜫꜭꜯ-ꜱꜳꜵꜷꜹꜻꜽꜿꝁꝃꝅꝇꝉꝋꝍꝏꝑꝓꝕꝗꝙꝛꝝꝟꝡꝣꝥꝧꝩꝫ]|
                [ꝭꝯꝱ-ꝸꝺꝼꝿꞁꞃꞅꞇꞌﬀ-ﬆﬓ-ﬗａ-ｚ𐐨-𐑏𝐚-𝐳𝑎-𝑔𝑖-𝑧𝒂-𝒛𝒶-𝒹𝒻𝒽-𝓃𝓅-𝓏𝓪-𝔃𝔞-𝔷𝕒-𝕫]|
                [𝖆-𝖟𝖺-𝗓𝗮-𝘇𝘢-𝘻𝙖-𝙯𝚊-𝚥𝛂-𝛚𝛜-𝛡𝛼-𝜔𝜖-𝜛𝜶-𝝎𝝐-𝝕𝝰-𝞈𝞊-𝞏𝞪-𝟂𝟄-𝟉𝟋]}xu
        end

        if RUBY_VERSION.to_f >= 1.9
            @@uppercase_re = /[[:upper:]]/
        else
            # Similarly, these are all the Unicode characters that are
            # uppercase, having Unicode category Lu; again, this can
            # be remove when we no longer support Ruby 1.8.
            @@uppercase_re = %r{[A-ZÀ-ÖØ-ÞĀĂĄĆĈĊČĎĐĒĔĖĘĚĜĞĠĢĤĦĨĪĬĮİ]|
                [ĲĴĶĹĻĽĿŁŃŅŇŊŌŎŐŒŔŖŘŚŜŞŠŢŤŦŨŪŬŮŰŲŴŶŸ-ŹŻŽƁ-ƂƄƆ-ƇƉ-ƋƎ-ƑƓ-ƔƖ-Ƙ]|
                [Ɯ-ƝƟ-ƠƢƤƦ-ƧƩƬƮ-ƯƱ-ƳƵƷ-ƸƼǄǇǊǍǏǑǓǕǗǙǛǞǠǢǤǦǨǪǬǮǱǴǶ-ǸǺǼǾȀȂȄȆȈȊȌ]|
                [ȎȐȒȔȖȘȚȜȞȠȢȤȦȨȪȬȮȰȲȺ-ȻȽ-ȾɁɃ-ɆɈɊɌɎͰͲͶΆΈ-ΊΌΎ-ΏΑ-ΡΣ-ΫϏϒ-ϔϘϚϜϞϠ]|
                [ϢϤϦϨϪϬϮϴϷϹ-ϺϽ-ЯѠѢѤѦѨѪѬѮѰѲѴѶѸѺѼѾҀҊҌҎҐҒҔҖҘҚҜҞҠҢҤҦҨҪҬҮҰҲҴҶҸҺҼҾ]|
                [Ӏ-ӁӃӅӇӉӋӍӐӒӔӖӘӚӜӞӠӢӤӦӨӪӬӮӰӲӴӶӸӺӼӾԀԂԄԆԈԊԌԎԐԒԔԖԘԚԜԞԠԢԤԱ-ՖႠ-ჅḀ]|
                [ḂḄḆḈḊḌḎḐḒḔḖḘḚḜḞḠḢḤḦḨḪḬḮḰḲḴḶḸḺḼḾṀṂṄṆṈṊṌṎṐṒṔṖṘṚṜṞṠṢṤṦṨṪṬṮṰṲṴṶ]|
                [ṸṺṼṾẀẂẄẆẈẊẌẎẐẒẔẞẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼẾỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴ]|
                [ỶỸỺỼỾἈ-ἏἘ-ἝἨ-ἯἸ-ἿὈ-ὍὙὛὝὟὨ-ὯᾸ-ΆῈ-ΉῘ-ΊῨ-ῬῸ-Ώℂℇℋ-ℍℐ-ℒℕℙ-ℝℤΩℨ]|
                [K-ℭℰ-ℳℾ-ℿⅅↃⰀ-ⰮⱠⱢ-ⱤⱧⱩⱫⱭ-ⱰⱲⱵⱾ-ⲀⲂⲄⲆⲈⲊⲌⲎⲐⲒⲔⲖⲘⲚⲜⲞⲠⲢⲤⲦⲨⲪⲬⲮⲰⲲⲴⲶⲸⲺⲼ]|
                [ⲾⳀⳂⳄⳆⳈⳊⳌⳎⳐⳒⳔⳖⳘⳚⳜⳞⳠⳢⳫⳭꙀꙂꙄꙆꙈꙊꙌꙎꙐꙒꙔꙖꙘꙚꙜꙞꙢꙤꙦꙨꙪꙬꚀꚂꚄꚆꚈꚊꚌꚎꚐꚒꚔꚖꜢꜤꜦꜨ]|
                [ꜪꜬꜮꜲꜴꜶꜸꜺꜼꜾꝀꝂꝄꝆꝈꝊꝌꝎꝐꝒꝔꝖꝘꝚꝜꝞꝠꝢꝤꝦꝨꝪꝬꝮꝹꝻꝽ-ꝾꞀꞂꞄꞆꞋＡ-Ｚ𐐀-𐐧𝐀-𝐙𝐴-𝑍]|
                [𝑨-𝒁𝒜𝒞-𝒟𝒢𝒥-𝒦𝒩-𝒬𝒮-𝒵𝓐-𝓩𝔄-𝔅𝔇-𝔊𝔍-𝔔𝔖-𝔜𝔸-𝔹𝔻-𝔾𝕀-𝕄𝕆𝕊-𝕐𝕬-𝖅𝖠-𝖹𝗔-𝗭𝘈-𝘡]|
                [𝘼-𝙕𝙰-𝚉𝚨-𝛀𝛢-𝛺𝜜-𝜴𝝖-𝝮𝞐-𝞨𝟊]}xu
        end

        # This method should become part of ruby as of 1.8.7
        def self.each_char(s)
            if block_given?
                s.scan(/./mu) do |x|
                    yield x
                end
            else
                s.scan(/./mu)
            end
        end

        def self.contains_uppercase(s)
            @@uppercase_re.match s
        end

        def self.contains_lowercase(s)
            @@lowercase_re.match s
        end

        # Stop someone writing all in capitals, or all lower case letters.
        def self.uses_mixed_capitals(s, allow_shorter_than = 20)
            # strip any URLs, as they tend to be all lower case and shouldn't count towards penalty
            s = s.gsub(/(https?):\/\/([^\s<>{}()]+[^\s.,<>{}()])/i, "")
            s = s.gsub(/(\s)www\.([a-z0-9\-]+)((?:\.[a-z0-9\-\~]+)+)((?:\/[^ <>{}()\n\r]*[^., <>{}()\n\r])?)/i, "")

            # count Roman alphabet lower and upper case letters
            capitals = 0
            lowercase = 0
            Validate.each_char(s) do |c|
                capitals = capitals + 1 if Validate.contains_uppercase(c)
                lowercase = lowercase + 1 if Validate.contains_lowercase(c)
            end

            # allow short things (e.g. short titles might be validly all caps)
            # (also avoids division by zero)
            return true if (capitals + lowercase < allow_shorter_than)

            # what proportion of roman A-Z letters are capitals?
            percent_capitals = capitals.to_f / (capitals + lowercase).to_f * 100
            #STDOUT.puts("percent_capitals " + percent_capitals.to_s)

            # anything more than 75% caps, or less than 0.5% capitals
            # XXX should check these against database of old FOI requests etc.
            if percent_capitals > 75.0 || percent_capitals < 0.5
                return false
            end

            return true
        end

        def self.email_match_regexp

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
            # XXX Update this for http://tools.ietf.org/html/rfc6530
            # N.B. intended for validating email addresses in their canonical form,
            # so does not allow folding whitespace

            specials = '()<>@,;:\\\\".\\[\\]'
            controls = '\\000-\\037\\177'
            # To add MacRuby support, see https://github.com/nex3/sass/pull/432
            highbit = if RUBY_VERSION.to_f < 1.9
                '\\200-\\377'
            else
                '\\u{80}-\\u{D7FF}\\u{E000}-\\u{FFFD}\\u{10000}-\\u{10FFFF}'
            end
            atext = "[^#{specials} #{controls}#{highbit}]"
            atom = "#{atext}+"
            dot_string = "#{atom}(\\.#{atom})*"
            qtext = "[^\"\\\\\\r\\n#{highbit}]"
            quoted_pair = '\\.'
            quoted_string = "\"(#{qtext}|#{quoted_pair})*\""
            local_part = "(#{dot_string}|#{quoted_string})"
            sub_domain = '[A-Za-z0-9][A-Za-z0-9-]*'
            domain = "#{sub_domain}(\\.#{sub_domain})*"

            return "#{local_part}@#{domain}"
        end

        def self.is_valid_email(addr)
            is_valid_address_re = Regexp.new("^#{Validate.email_match_regexp}\$")

            return addr =~ is_valid_address_re
        end

        # For finding email addresses in a body of text.
        # XXX Less exact than the one above, but I had problems in Ruby's
        # regexp engine with the one above crashing it.
        def self.email_find_regexp
            return Regexp.new("(\\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}\\b)")
        end


        # is_valid_postcode POSTCODE
        # Return true if POSTCODE is in the proper format for a UK postcode. Does not
        # require spaces in the appropriate place.
        def self.is_valid_postcode(postcode)
            return Validate.postcode_match_internal(postcode, "^", "$")
        end

        # is_valid_partial_postcode POSTCODE
        # Returns true if POSTCODE is in the proper format for the first part of a UK
        # postcode. Expects a stripped string.
        def self.is_valid_partial_postcode(postcode)

            # Our test postcode
            if (postcode.match(/^zz9$/i))
                return true
            end

            fst = 'ABCDEFGHIJKLMNOPRSTUWYZ'
            sec = 'ABCDEFGHJKLMNOPQRSTUVWXY'
            thd = 'ABCDEFGHJKSTUW'
            fth = 'ABEHMNPRVWXY'
            num0 = '123456789' # Technically allowed in spec, but none exist
            num = '0123456789'

            if (postcode.match(/^[#{fst}][#{num0}]$/i) ||
                postcode.match(/^[#{fst}][#{num0}][#{num}]$/i) ||
                postcode.match(/^[#{fst}][#{sec}][#{num}]$/i) ||
                postcode.match(/^[#{fst}][#{sec}][#{num0}][#{num}]$/i) ||
                postcode.match(/^[#{fst}][#{num0}][#{thd}]$/i) ||
                postcode.match(/^[#{fst}][#{sec}][#{num0}][#{fth}]$/i
                ))
                return true
            else
                return false
            end
        end

        def self.contains_postcode?(postcode)
            return Validate.postcode_match_internal(postcode, "\\b", "\\b")
        end

        def self.postcode_match_internal(postcode, pre, post)
            # Our test postcode
            if (postcode.match(/#{pre}zz9\s*9z[zy]#{post}/i))
                return true
            end

            # See http://www.govtalk.gov.uk/gdsc/html/noframes/PostCode-2-1-Release.htm
            inn  = 'ABDEFGHJLNPQRSTUWXYZ'
            fst = 'ABCDEFGHIJKLMNOPRSTUWYZ'
            sec = 'ABCDEFGHJKLMNOPQRSTUVWXY'
            thd = 'ABCDEFGHJKSTUW'
            fth = 'ABEHMNPRVWXY'
            num0 = '123456789' # Technically allowed in spec, but none exist
            num = '0123456789'
            nom = '0123456789'
            gap = '\s\.'

            if (postcode.match(/#{pre}[#{fst}][#{num0}][#{gap}]*[#{nom}][#{inn}][#{inn}]#{post}/i) ||
                postcode.match(/#{pre}[#{fst}][#{num0}][#{num}][#{gap}]*[#{nom}][#{inn}][#{inn}]#{post}/i) ||
                postcode.match(/#{pre}[#{fst}][#{sec}][#{num}][#{gap}]*[#{nom}][#{inn}][#{inn}]#{post}/i) ||
                postcode.match(/#{pre}[#{fst}][#{sec}][#{num0}][#{num}][#{gap}]*[#{nom}][#{inn}][#{inn}]#{post}/i) ||
                postcode.match(/#{pre}[#{fst}][#{num0}][#{thd}][#{gap}]*[#{nom}][#{inn}][#{inn}]#{post}/i) ||
                postcode.match(/#{pre}[#{fst}][#{sec}][#{num0}][#{fth}][#{gap}]*[#{nom}][#{inn}][#{inn}]#{post}/i))
                return true
            else
                return false
            end
        end

        def self.is_valid_lon_lat(lon, lat)
          return (lon.to_s.match(/^\s*-?\d+\.?\d*\s*$/) && lat.to_s.match(/^\s*-?\d+\.?\d*\s*$/))
        end
    end
end


