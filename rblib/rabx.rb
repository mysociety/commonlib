# rabx.rb:
# Client side functions to call RABX services, but via REST/JSON, rather than
# using netstrings as for older Perl/PHP clients.
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
#
require 'open-uri'
require 'json'
require 'cgi'

module MySociety

  module RABX
    
    class RABXError < StandardError
      
      alias :orig_to_s :to_s
      
      def initialize(value, text, extradata)
        @value = value
        @text = text
        @extradata = extradata
      end
      
      def to_s
        ret = "#{@value}: #{@text}"
        if @extradata
          ret += @extradata.to_s
        end
        return ret
      end
      
    end
    
    def RABX.call_rest_rabx(base_url, params_init)
      params = []
      params_init.each do |param|
        if param == nil
          params << ''
        else
          params << param
        end
      end
      params_quoted = params.map{ |param| CGI::escape(param) }
      params_joined = params_quoted.join("/")
      url = base_url.gsub('.cgi', '-rest.cgi') + '?' + params_joined
      content = open(url).read
      result = JSON.parse(content)
      if result.has_key? 'error_value'
        raise RABXError.new(result['error_value'], result['error_text'], result['error_extradata'])
      end
      return result
    end
    
  end
end
