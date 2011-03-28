# Rake task for running commonlib/rblib tests
namespace :test do 
  desc "Run the ruby tests in commonlib"
  task :commonlib do 
    Dir.glob(File.join(File.dirname(__FILE__), '*_test.rb')).each do |filename|
      sh "ruby #{filename} " 
    end
  end
  
  task :commonlib_all do 
    Dir.glob(File.join(File.dirname(__FILE__), '*_test.rb')).each do |filename|
      sh "ruby #{filename} " 
    end
  end
  
end