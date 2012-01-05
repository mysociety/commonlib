# survey.rb
# Client interface for survey.mysociety.org

require 'config'
require 'digest/sha1'
require 'net/http'
require 'securerandom'
require 'uri'

module MySociety
    class Survey
        def initialize(site, email)
            # XXXX It’s not right to hard-code this, but I can’t think of a good general
            #      solution.
            MySociety::Config.set_file File.join(File.dirname(__FILE__), "..", "..", "config", "general")
            
            @site = site
            
            @survey_url = MySociety::Config.get "SURVEY_URL"
            @survey_secret = MySociety::Config.get "SURVEY_SECRET"
            
            @user_code = Digest::SHA1.hexdigest "#{email}-#{@survey_secret}"
            @auth_signature = generate_auth_signature
        end
        
        # Return whether or not survey was already done for this user
        def already_done?
            return do_command "querydone"
        end

        # Clears memory that this survey was done, allowing a new one
        def allow_new_survey
            return do_command "allownewsurvey"
        end
        
        private
        def generate_auth_signature
            salt = SecureRandom.hex(8)
            sha = Digest::SHA1.hexdigest "#{salt}-#{@survey_secret}-#{@user_code}"
            return "#{sha}-#{salt}"
        end
        
        def do_command(command)
            useragent = "Ruby survey client, version 1"
            
            result = Net::HTTP.post_form(URI.parse(@survey_url), {
                command => 1,
                "sourceidentifier" => @site,
                "user_code" => @user_code,
                "auth_signature" => @auth_signature,
            })
            
            if result.code != "200"
                raise "Failed to post to #{@survey_url}: #{result.code} #{result.message}"
            end
            
            r = result.body.strip
            if r == "1"
                return true;
            elsif r == "0"
                return false;
            else
                raise "Error returned from survey service: #{r}"
            end
        end
    end
end
