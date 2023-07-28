# -*- encoding : utf-8 -*-
$:.push(File.join(File.dirname(__FILE__), '..'))
require 'config'
require 'survey'
require 'test/unit'
require 'mocha/test_unit'
require 'webmock/test_unit'

class TestSurvey < Test::Unit::TestCase

  def setup
    MySociety::Config.stubs(:get).
      with('SURVEY_URL').returns('https://example.com/survey')

    MySociety::Config.stubs(:get).
      with('SURVEY_SECRET').returns('ABC123')

    MySociety::Config.stubs(:get).
      with('SSL_CA_PATH', '/etc/ssl/certs/').returns('/etc/ssl/certs/')

    @survey = MySociety::Survey.new "survey_test.rb", "robin@mysociety.org"
  end

  def test_submit_ok
      # Just check we can submit with no exceptions
      return_url = "http://localhost/"

      stub_request(:post, 'https://example.com/survey')
        .with do |req|
          data = URI.decode_www_form(req.body).to_h
          data['foo'] == 'bar' && data['return_url'] == return_url
        end
        .to_return(status: 302, headers: { 'Location' => return_url })

      assert_equal(return_url, @survey.submit("foo" => "bar", "return_url" => return_url))
  end

  def test_already_done_no
      stub_request(:post, 'https://example.com/survey')
        .to_return(status: 200, body: '0')

      survey_we_never_do = MySociety::Survey.new "survey_test.rb", "neverneverboy@mysociety.org"
      assert !survey_we_never_do.already_done?
  end

  def test_already_done_yes
      stub_request(:post, 'https://example.com/survey')
        .to_return(status: 200, body: '1')

      @survey.submit("foo" => "bar", "return_url" => "")
      assert @survey.already_done?
  end

  def test_allow_new_survey
      stub_request(:post, 'https://example.com/survey')
        .to_return(status: 200, body: '1')

      @survey.submit("foo" => "bar", "return_url" => "")
      assert @survey.already_done?

      stub_request(:post, 'https://example.com/survey')
        .to_return(status: 200, body: '0')

      @survey.allow_new_survey
      assert !@survey.already_done?

      stub_request(:post, 'https://example.com/survey')
        .to_return(status: 200, body: '1')

      @survey.submit("foo" => "bar", "return_url" => "")
      assert @survey.already_done?
  end
end
