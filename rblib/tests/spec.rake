# Rake task for running commonlib/rblib tests within rspec
require 'rubygems'

namespace :spec do

  desc "Run the ruby test in commonlib in rspec format"
  RSpec::Core::RakeTask.new(:commonlib) do |t|
    t.ruby_opts = ['-rtest/unit']
    t.pattern = File.join(File.dirname(__FILE__), '*_{test,spec}.rb')
  end

end
