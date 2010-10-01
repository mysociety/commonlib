namespace :test do 
  desc "Run the ruby tests in commonlib"
  task :commonlib do 
    Dir.glob(File.join(File.dirname(__FILE__), '*.rb')).each do |filename|
      sh "ruby #{filename} " 
    end
  end
end