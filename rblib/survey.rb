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
            # Assume you have called MySociety::Config.set_file
            
            @site = site
            
            @survey_url = MySociety::Config.get "SURVEY_URL"
            @survey_secret = MySociety::Config.get "SURVEY_SECRET"
            
            @user_code = Digest::SHA1.hexdigest "#{email}-#{@survey_secret}"
            @auth_signature = generate_auth_signature
        end
        
        def submit(results)
            return do_command results
        end
        
        # Return whether or not survey was already done for this user
        def already_done?
            return do_command "querydone" => 1
        end

        # Clears memory that this survey was done, allowing a new one
        def allow_new_survey
            return do_command "allownewsurvey" => 1
        end
        
        # The parameters that are required to communicate with
        # the survey service. If you’re submitting a form
        # directly, you need to include these and return_url;
        # the survey service will issue a 302 redirect to
        # return_url once the results have been stored.
        def required_params
            return {
                "sourceidentifier" => @site,
                "user_code" => @user_code,
                "auth_signature" => @auth_signature,
            }
        end
        
        private
        def generate_auth_signature
            salt = SecureRandom.hex(8)
            sha = Digest::SHA1.hexdigest "#{salt}-#{@survey_secret}-#{@user_code}"
            return "#{sha}-#{salt}"
        end
        
        def do_command(params = {})
            useragent = "Ruby survey client, version 1"
            
            params.update(self.required_params)
            result = Net::HTTP.post_form(URI.parse(@survey_url), params)
            
            if result.code == "302"
                return result.header["Location"]
            elsif result.code != "200"
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
