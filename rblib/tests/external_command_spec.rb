# This is a test of the external_command library

script_dir = File.join(File.dirname(__FILE__), 'external_command_scripts')
true_script = File.join(script_dir, "true.sh")
false_script = File.join(script_dir, "false.sh")
output_script = File.join(script_dir, "output.sh")
cat_script = File.join(script_dir, "cat.sh")

require 'external_command'

describe "when running ExternalCommand" do

    it "should get correct status code for true.sh" do
        t = ExternalCommand.new(true_script).run()
        t.status.should == 0
        t.out.should == ""
        t.err.should == ""
    end

    it "should get correct status code for false.sh" do
        f = ExternalCommand.new(false_script).run()
        f.status.should == 1
        f.out.should == ""
        f.err.should == ""
    end

    it "should get stdout and stderr" do
        f = ExternalCommand.new(output_script, "out", "err", "10", "23").run()
        f.status.should == 23
        f.out.should == (0..9).map {|i| "out #{i}\n"}.join("")
        f.err.should == (0..9).map {|i| "err #{i}\n"}.join("")
    end

    it "should work with large amounts of data" do
        f = ExternalCommand.new(output_script, "a longer output line", "a longer error line", "10000", "5").run()
        f.status.should == 5
        f.out.should == (0..9999).map {|i| "a longer output line #{i}\n"}.join("")
        f.err.should == (0..9999).map {|i| "a longer error line #{i}\n"}.join("")
    end

    it "should handle stdin" do
        f = ExternalCommand.new(cat_script).run("Here we are\nThis part will be ignored")
        f.status.should == 0
        f.out.should == "Here we are\n"
    end
end

