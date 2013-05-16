$:.push(File.join(File.dirname(__FILE__), '..'))
require 'config'
require 'survey'
require 'test/unit'

# We should really use a synthetic config file for testing, but the survey
# module requires a real running instance of the mySociety survey service
# and so can’t really be tested in splendid isolation. Therefore we make an
# educated guess at where we might find a config file that contains connection
# details for a running instance of the service.
MySociety::Config::set_file(File.join(File.dirname(__FILE__), "..", "..", "..", "config", "general"))

class TestSurvey < Test::Unit::TestCase

  def setup
    @survey = MySociety::Survey.new "survey_test.rb", "robin@mysociety.org"
  end

  def test_submit_ok
      # Just check we can submit with no exceptions
      return_url = "http://localhost/"
      assert_equal(return_url, @survey.submit("foo" => "bar", "return_url" => return_url))
  end

  def test_already_done_no
      survey_we_never_do = MySociety::Survey.new "survey_test.rb", "neverneverboy@mysociety.org"
      assert !survey_we_never_do.already_done?
  end

  def test_already_done_yes
      @survey.submit("foo" => "bar", "return_url" => "")
      assert @survey.already_done?
  end

  def test_allow_new_survey
      @survey.submit("foo" => "bar", "return_url" => "")
      assert @survey.already_done?

      @survey.allow_new_survey
      assert !@survey.already_done?

      @survey.submit("foo" => "bar", "return_url" => "")
      assert @survey.already_done?
  end
end
