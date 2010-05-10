# url_mapper.rb:
#
# Some functions for transforming relative URLs within an application
# to absolute URLs pointing at either the main application or the admin 
# interface (assuming this may be accessed via a different host).
#
# Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
# Email: louise@mysociety.org; WWW: http://www.mysociety.org/
#
module MySociety

  module UrlMapper
  
    def self.included(base) 
      base.extend ClassMethods
    end
  
    module ClassMethods
      
      def url_mapper
        include InstanceMethods
      end

    end
  
    module InstanceMethods
      
      # Removes any leading /admin directory from the URL, and prefixes it with
      # the prefix defined in ADMIN_BASE_URL in the config
      def admin_url(relative_path)
        admin_url_prefix = MySociety::Config.get("ADMIN_BASE_URL", "/admin/")
        relative_path = relative_path.gsub(/^\/admin(\/|$)|^\//, '') 
        return admin_url_prefix + relative_path
      end

      # Prefixes a relative URL with the domain definted in DOMAIN in the config
      def main_url(relative_path)
        url_prefix = "http://" + MySociety::Config.get("DOMAIN", '127.0.0.1:3000')
        return url_prefix + relative_path
      end
      
    end
  end
end