# email.rb - email handling functions
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
require 'tmail'
require 'mahoro'
require 'mapi/msg'
require 'tmpdir'

module MySociety

  module Email
    
    @file_extension_to_mime_type = {
        "txt" => 'text/plain',
        "pdf" => 'application/pdf',
        "rtf" => 'application/rtf',
        "doc" => 'application/vnd.ms-word',
        "docx" => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        "xls" => 'application/vnd.ms-excel',
        "xlsx" => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        "ppt" => 'application/vnd.ms-powerpoint',
        "pptx" => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        "oft" => 'application/vnd.ms-outlook',
        "msg" => 'application/vnd.ms-outlook',
        "tnef" => 'application/ms-tnef',
        "tif" => 'image/tiff',
        "gif" => 'image/gif',
        "jpg" => 'image/jpeg', # XXX add jpeg
        "png" => 'image/png',
        "bmp" => 'image/bmp',
        "html" => 'text/html', # XXX add htm
        "vcf" => 'text/x-vcard',
        "zip" => 'application/zip',
        "delivery-status" => 'message/delivery-status'
    }

    @file_extension_to_mime_type_rev = @file_extension_to_mime_type.invert

    # Returns part of an email which contains main body text, or nil if there isn't one
    def self.get_main_body_text_part(mail)
      leaves = get_attachment_leaves(mail)
      
      # Find first part which is text/plain or text/html
      # (We have to include HTML, as increasingly there are mail clients that
      # include no text alternative for the main part, and we don't want to
      # instead use the first text attachment 
      text_types = ['text/plain', 'text/html']
      leaves.each{ |part| return part if text_types.include?(part.content_type) }

      # Otherwise first part which is any sort of text
      leaves.each{ |part| return part if part.main_type == 'text' }

      # ... or if none, consider first part 
      part = leaves[0]
      # if it is a known type then don't use it, return no body (nil)
      if mimetype_to_extension(part.content_type)
        # this is guess of case where there are only attachments, no body text
        # e.g. http://www.whatdotheyknow.com/request/cost_benefit_analysis_for_real_n
        return nil
      end
      # otherwise return it assuming it is text (sometimes you get things
      # like binary/octet-stream, or the like, which are really text - XXX if
      # you find an example, put URL here - perhaps we should be always returning
      # nil in this case)
      return part
    end
    
    # Choose the best part of an email to display
    # (This risks losing info if the unchosen alternative is the only one to contain 
    # useful info, but let's worry about that another time)
    def self.get_best_part_for_display(mail)
      # Choose best part from alternatives
      best_part = nil
      # Take the last text/plain one, or else the first one
      mail.parts.each do |part|
        if not best_part
          best_part = part
        elsif part.content_type == 'text/plain'
          best_part = part
        end
      end
      # Take an HTML one as even higher priority. (They tend to render better than text/plain) 
      mail.parts.each do |part|
        if part.content_type == 'text/html'
          best_part = part
        end
      end
      best_part
    end
    
    def self.get_attachment_leaves(mail)
      @count_parts_count = 0
      return _get_attachment_leaves_recursive(mail)
    end
    
    def self._get_attachment_leaves_recursive(mail, within_rfc822_attachment = nil)
      leaves_found = []
      if mail.multipart?
        # pick best part
        if mail.sub_type == 'alternative'
          best_part = get_best_part_for_display(mail)
          leaves_found += _get_attachment_leaves_recursive(best_part, within_rfc822_attachment)
        else
          # add all parts
          mail.parts.each do |part|
            leaves_found += _get_attachment_leaves_recursive(part, within_rfc822_attachment)
          end
        end
      else
        
        normalise_content_type(mail)
        expand_single_attachment(mail)

        # If the part is an attachment of email
        if is_attachment?(mail)
          leaves_found += _get_attachment_leaves_recursive(mail.rfc822_attachment, mail.rfc822_attachment)
        else
          # Store leaf
          mail.within_rfc822_attachment = within_rfc822_attachment
          @count_parts_count += 1
          mail.url_part_number = @count_parts_count
          leaves_found += [mail]
        end
      end
      return leaves_found
    end
    
    def self.is_attachment?(part)
      attachment_types = ['message/rfc822', 'application/vnd.ms-outlook', 'application/ms-tnef']
      if attachment_types.include?(part.content_type)
        return true
      end
      return false
    end
    
    def self.expand_single_attachment(part)
      part_filename = Mail.get_part_file_name(part)
      if part.content_type == 'message/rfc822'
        # An email attached as text
        # e.g. http://www.whatdotheyknow.com/request/64/response/102
        begin
          part.rfc822_attachment = Mail.parse(part.body)
        rescue
          part.rfc822_attachment = nil
          part.content_type = 'text/plain'
        end
      elsif part.content_type == 'application/vnd.ms-outlook' || 
          part_filename && filename_to_mimetype(part_filename) == 'application/vnd.ms-outlook'
        # An email attached as an Outlook file
        # e.g. http://www.whatdotheyknow.com/request/chinese_names_for_british_politi
        begin
          msg = Mapi::Msg.open(StringIO.new(part.body))
          part.rfc822_attachment = Mail.parse(msg.to_mime.to_s)
        rescue
          part.rfc822_attachment = nil
          part.content_type = 'application/octet-stream'
        end
      elsif part.content_type == 'application/ms-tnef' 
        # A set of attachments in a TNEF file
        begin
          part.rfc822_attachment = TNEF.as_tmail(part.body)
        rescue
          part.rfc822_attachment = nil
          # Attached mail didn't parse, so treat as binary
          mail.content_type = 'application/octet-stream'
        end
      end
    end
    
    # Given file name and its content, return most likely type
    def self.filename_and_content_to_mimetype(filename, content)
      # Try filename
      ret = filename_to_mimetype(filename)
      if !ret.nil?
        return ret
      end

      # Otherwise look inside the file to work out the type.
      # Mahoro is a Ruby binding for libmagic.
      m = Mahoro.new(Mahoro::MIME)
      mahoro_type = m.buffer(content)
      mahoro_type.strip!
      # XXX we shouldn't have to check empty? here, but Mahoro sometimes returns a blank line :(
      # e.g. for InfoRequestEvent 17930
      if mahoro_type.nil? || mahoro_type.empty?
        return nil
      end
      # text/plain types sometimes come with a charset
      mahoro_type.match(/^(.*);/)
      if $1
        mahoro_type = $1
      end
      # see if looks like a content type, or has something in it that does
      # and return that
      # mahoro returns junk "\012- application/msword" as mime type.
      mahoro_type.match(/([a-z0-9.-]+\/[a-z0-9.-]+)/)
      if $1
        return $1
      end
      # otherwise we got junk back from mahoro
      return nil
    end

    def self.filename_to_mimetype(filename)
      if !filename
        return nil
      end
      if filename.match(/\.([^.]+)$/i)
        lext = $1.downcase
        if @file_extension_to_mime_type.include?(lext)
          return @file_extension_to_mime_type[lext]
        end
      end
      return nil
    end
    
    def self.mimetype_to_extension(mime)
      if @file_extension_to_mime_type_rev.include?(mime)
        return @file_extension_to_mime_type_rev[mime]
      end
      return nil
    end
    
    # Normalise a mail part's content_type for display
    # Use standard content types for Word documents etc.
    def self.normalise_content_type(mail_part)
      
      # Don't allow nil content_types
      if mail_part.content_type.nil?
        mail_part.content_type = 'application/octet-stream'
      end
      
      # PDFs often come with this mime type, fix it up for view code
      if mail_part.content_type == 'application/octet-stream'
        part_file_name = Mail.get_part_file_name(mail_part)
        calc_mime = filename_and_content_to_mimetype(part_file_name, mail_part.body)
        if calc_mime
          mail_part.content_type = calc_mime
        end
      end 
      
      if ['application/excel', 'application/msexcel', 'application/x-ms-excel'].include?(mail_part.content_type)
        mail_part.content_type = 'application/vnd.ms-excel'
      end
      
      if ['application/mspowerpoint', 'application/x-ms-powerpoint'].include?(mail_part.content_type)
        mail_part.content_type = 'application/vnd.ms-powerpoint' 
      end
      
      if ['application/msword', 'application/x-ms-word'].include?(mail_part.content_type)
        mail_part.content_type = 'application/vnd.ms-word'
      end
      
      if mail_part.content_type == 'application/x-zip-compressed'
        mail_part.content_type = 'application/zip'
      end

      if mail_part.content_type == 'application/acrobat'
        mail_part.content_type = 'application/pdf'
      end
      
    end

    def self._get_attachment_text_internal_one_file(content_type, body)
      text = ''
      # XXX - tell all these command line tools to return utf-8
      if content_type == 'text/plain'
        text += body + "\n\n"
      else
        tempfile = Tempfile.new('emailextract')
        tempfile.print body
        tempfile.flush
        if content_type == 'application/vnd.ms-word'
          system("/usr/bin/wvText " + tempfile.path + " " + tempfile.path + ".txt")
          # Try catdoc if we get into trouble (e.g. for InfoRequestEvent 2701)
          if not File.exists?(tempfile.path + ".txt")
            IO.popen("/usr/bin/catdoc " + tempfile.path, "r") do |child|
              text += child.read() + "\n\n"
            end
          else
            text += File.read(tempfile.path + ".txt") + "\n\n"
            File.unlink(tempfile.path + ".txt")
          end
        elsif content_type == 'application/rtf'
          # catdoc on RTF prodcues less comments and extra bumf than --text option to unrtf
          IO.popen("/usr/bin/catdoc " + tempfile.path, "r") do |child|
            text += child.read() + "\n\n"
          end
        elsif content_type == 'text/html'
          # lynx wordwraps links in its output, which then don't get formatted properly
          # by WhatDoTheyKnow. We use elinks instead, which doesn't do that.
          IO.popen("/usr/bin/elinks -dump-charset utf-8 -force-html -dump " + tempfile.path, "r") do |child|
            text += child.read() + "\n\n"
          end
        elsif content_type == 'application/vnd.ms-excel'
          # Bit crazy using /usr/bin/strings - but xls2csv, xlhtml and
          # py_xls2txt only extract text from cells, not from floating
          # notes. catdoc may be fooled by weird character sets, but will
          # probably do for UK FOI requests.
          IO.popen("/usr/bin/strings " + tempfile.path, "r") do |child|
            text += child.read() + "\n\n"
          end
        elsif content_type == 'application/vnd.ms-powerpoint'
            # ppthtml seems to catch more text, but only outputs HTML when
            # we want text, so just use catppt for now
            IO.popen("/usr/bin/catppt " + tempfile.path, "r") do |child|
                text += child.read() + "\n\n"
            end
        elsif content_type == 'application/pdf'
          IO.popen("/usr/bin/pdftotext " + tempfile.path + " -", "r") do |child|
            text += child.read() + "\n\n"
          end
        elsif content_type == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
          # This is Microsoft's XML office document format.
          # Just pull out the main XML file, and strip it of text.
          xml = ''
          IO.popen("/usr/bin/unzip -qq -c " + tempfile.path + " word/document.xml", "r") do |child|
            xml += child.read() + "\n\n"
          end
          doc = REXML::Document.new(xml)
          text += doc.each_element( './/text()' ){}.join(" ")
        elsif content_type == 'application/zip'
          # recurse into zip files
          zip_file = Zip::ZipFile.open(tempfile.path)
          for entry in zip_file
            if entry.file?
              filename = entry.to_s
              begin 
                body = entry.get_input_stream.read
              rescue
                # move to next attachment silently if there were problems
                # XXX really should reduce this to specific exceptions?
                # e.g. password protected
                next
              end
              calc_mime = filename_to_mimetype(filename)
              if calc_mime
                content_type = calc_mime
              else
                content_type = 'application/octet-stream'
              end
        
              #STDERR.puts("doing file " + filename + " content type " + content_type)
              text += _get_attachment_text_internal_one_file(content_type, body)
            end
          end
        end
        tempfile.close
      end

      return text
    end
  
    # Given a main text part, converts it to text
    def self.convert_part_body_to_text(part)
      if part.nil?
        text = "[ Email has no body, please see attachments ]"
        text_charset = "utf-8"
      else
        text = part.body
        text_charset = part.charset
        if part.content_type == 'text/html'
          # e.g. http://www.whatdotheyknow.com/request/35/response/177
          # XXX This is a bit of a hack as it is calling a convert to text routine.
          # Could instead call a sanitize HTML one.
          text = _get_attachment_text_internal_one_file(part.content_type, text)
        end
      end

      # Fix DOS style linefeeds to Unix style ones (or other later regexps won't work)
      # Needed for e.g. http://www.whatdotheyknow.com/request/60/response/98
      text = text.gsub(/\r\n/, "\n")

      # Compress extra spaces down to save space, and to stop regular expressions
      # breaking in strange extreme cases. e.g. for
      # http://www.whatdotheyknow.com/request/spending_on_consultants
      text = text.gsub(/ +/, " ")

      return text
    end
  
    # Lotus notes quoting yeuch!
    def self.remove_lotus_quoting(text, name, replacement = "FOLDED_QUOTED_SECTION")
      text = text.dup
      name = Regexp.escape(name)

      # To end of message sections
      # http://www.whatdotheyknow.com/request/university_investment_in_the_arm
      text.gsub!(/^#{name}[^\n]+\nSent by:[^\n]+\n.*/ims, "\n\n" + replacement)

      # Some other sort of forwarding quoting
      # http://www.whatdotheyknow.com/request/224/response/326
      text.gsub!(/^#{name}[^\n]+\n[0-9\/:\s]+\s+To\s+FOI requests at.*/ims, "\n\n" + replacement)

      # http://www.whatdotheyknow.com/request/how_do_the_pct_deal_with_retirin_33#incoming-930
      # http://www.whatdotheyknow.com/request/229/response/809
      text.gsub!(/^From: [^\n]+\nSent: [^\n]+\nTo:\s+['"?]#{name}['"]?\nSubject:.*/ims, "\n\n" + replacement)

      return text
    end
  
  
    # Remove quoted sections from emails (eventually the aim would be for this
    # to do as good a job as GMail does) XXX bet it needs a proper parser
    # XXX and this FOLDED_QUOTED_SECTION stuff is a mess
    def self.remove_quoted_sections(text, replacement = "FOLDED_QUOTED_SECTION")
      text = text.dup
      replacement = "\n" + replacement + "\n"

      # First do this peculiar form of quoting, as the > single line quoting
      # further below messes with it. Note the carriage return where it wraps -
      # this can happen anywhere according to length of the name/email. e.g.
      # >>> D K Elwell <[email address]> 17/03/2008
      # 01:51:50 >>>
      # http://www.whatdotheyknow.com/request/71/response/108
      # http://www.whatdotheyknow.com/request/police_powers_to_inform_car_insu
      # http://www.whatdotheyknow.com/request/secured_convictions_aided_by_cct
      multiline_original_message = '(' + '''>>>.* \d\d/\d\d/\d\d\d\d\s+\d\d:\d\d(?::\d\d)?\s*>>>''' + ')'
      text.gsub!(/^(#{multiline_original_message}\n.*)$/ms, replacement)

      # Single line sections
      text.gsub!(/^(>.*\n)/, replacement)
      text.gsub!(/^(On .+ (wrote|said):\n)/, replacement)

      # Multiple line sections
      # http://www.whatdotheyknow.com/request/identity_card_scheme_expenditure
      # http://www.whatdotheyknow.com/request/parliament_protest_actions
      # http://www.whatdotheyknow.com/request/64/response/102
      # http://www.whatdotheyknow.com/request/47/response/283
      # http://www.whatdotheyknow.com/request/30/response/166
      # http://www.whatdotheyknow.com/request/52/response/238
      # http://www.whatdotheyknow.com/request/224/response/328 # example with * * * * *
      # http://www.whatdotheyknow.com/request/297/response/506
      ['-', '_', '*', '#'].each do |score|
          text.sub!(/(Disclaimer\s+)?  # appears just before
                      (
                          \s*(?:[#{score}]\s*){8,}\s*\n.*? # top line
                          (disclaimer:\n|confidential|received\sthis\semail\sin\serror|virus|intended\s+recipient|monitored\s+centrally|intended\s+(for\s+|only\s+for\s+use\s+by\s+)the\s+addressee|routinely\s+monitored|MessageLabs|unauthorised\s+use)
                          .*?((?:[#{score}]\s*){8,}\s*\n|\z) # bottom line OR end of whole string (for ones with no terminator XXX risky)
                      )
                     /imx, replacement)
      end

      # Special paragraphs
      # http://www.whatdotheyknow.com/request/identity_card_scheme_expenditure
      text.gsub!(/^[^\n]+Government\s+Secure\s+Intranet\s+virus\s+scanning
                  .*?
                  virus\sfree\.
                  /imx, replacement)
      text.gsub!(/^Communications\s+via\s+the\s+GSi\s+
                  .*?
                  legal\spurposes\.
                  /imx, replacement)
      # http://www.whatdotheyknow.com/request/net_promoter_value_scores_for_bb
      text.gsub!(/^http:\/\/www.bbc.co.uk
                  .*?
                  Further\s+communication\s+will\s+signify\s+your\s+consent\s+to\s+this\.
                  /imx, replacement)


      # To end of message sections
      # http://www.whatdotheyknow.com/request/123/response/192
      # http://www.whatdotheyknow.com/request/235/response/513
      # http://www.whatdotheyknow.com/request/445/response/743
      original_message = 
          '(' + '''----* This is a copy of the message, including all the headers. ----*''' + 
          '|' + '''----*\s*Original Message\s*----*''' +
          '|' + '''----*\s*Forwarded message.+----*''' +
          '|' + '''----*\s*Forwarded by.+----*''' +
          ')'
      # Could have a ^ at start here, but see messed up formatting here:
      # http://www.whatdotheyknow.com/request/refuse_and_recycling_collection#incoming-842
      text.gsub!(/(#{original_message}\n.*)$/mi, replacement)


      # Some silly Microsoft XML gets into parts marked as plain text.
      # e.g. http://www.whatdotheyknow.com/request/are_traffic_wardens_paid_commiss#incoming-401
      # Don't replace with "replacement" as it's pretty messy
      text.gsub!(/<\?xml:namespace[^>]*\/>/, " ")

      return text
    end
    
    def self.clean_linebreaks(text)
      text.strip!
      text = text.gsub(/\n/, '<br>')
      text = text.gsub(/(?:<br>\s*){2,}/, '<br><br>') # remove excess linebreaks that unnecessarily space it out
      return text
    end
  
    # A subclass of TMail that adds some extra attributes
    class Mail < TMail::Mail
      attr_accessor :url_part_number
      attr_accessor :rfc822_attachment # when a whole email message is attached as text
      attr_accessor :within_rfc822_attachment # for parts within a message attached as text (for getting subject mainly)
    
      # Hack round bug in TMail's MIME decoding. Example request which provokes it:
      # http://rubyforge.org/tracker/index.php?func=detail&aid=21810&group_id=4512&atid=17370
      def parse(raw_data)
        TMail::Mail.parse(raw_data.gsub(/; boundary=\s+"/ims,'; boundary="'))
      end
  
      def Mail.get_part_file_name(part)
        file_name = (part['content-location'] &&
                      part['content-location'].body) ||
                    part.sub_header("content-type", "name") ||
                    part.sub_header("content-disposition", "filename")
      end
    end
  
    class TNEF

      # Extracts all attachments from the given TNEF file as a TMail::Mail object
      # The TNEF file also contains the message body, but in general this is the
      # same as the message body in the message proper.
      def self.as_tmail(content)
        main = TMail::Mail.new
        main.set_content_type 'multipart', 'mixed', { 'boundary' => TMail.new_boundary }
        Dir.mktmpdir do |dir|
          IO.popen("/usr/bin/tnef -K -C #{dir}", "w") do |f|
            f.write(content)
            f.close
            if $?.signaled?
              raise IOError, "tnef exited with signal #{$?.termsig}"
            end
            if $?.exited? && $?.exitstatus != 0
              raise IOError, "tnef exited with status #{$?.exitstatus}"
            end
          end
          found = 0
          Dir.new(dir).sort.each do |file| # sort for deterministic behaviour
            if file != "." && file != ".."
              file_content = File.open("#{dir}/#{file}", "r").read
              attachment = TMail::Mail.new
              attachment['content-location'] = file
              attachment.body = file_content
              main.parts << attachment
              found += 1
            end
          end
          if found == 0
            raise IOError, "tnef produced no attachments"
          end
        end
        main
      end

    end
  end
end