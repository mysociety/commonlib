$:.push(File.join(File.dirname(__FILE__), '..'))
require 'survey'
require 'test/unit'
# Use rspec if loadable 
begin 
  require 'spec/test/unit'
rescue LoadError
  puts "Not using rspec"
end
class TestSurvey < Test::Unit::TestCase

  def test_already_done
      survey = MySociety::Survey.new "survey_test.rb", "robin@mysociety.org"
      assert !survey.already_done?
  end
  
end