# Rake task for running commonlib/rblib tests within rspec
require 'rubygems'

namespace :spec do

  desc "Run the ruby test in commonlib in rspec format"
  RSpec::Core::RakeTask.new(:commonlib) do |t|
    t.pattern = File.join(File.dirname(__FILE__), '*_spec.rb')
  end

end
