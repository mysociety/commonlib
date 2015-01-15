# coding: utf-8
# This is a test of the external_command library
$:.push(File.join(File.dirname(__FILE__), '..'))

script_dir = File.join(File.dirname(__FILE__), 'external_command_scripts')
true_script = File.join(script_dir, "true.sh")
false_script = File.join(script_dir, "false.sh")
output_script = File.join(script_dir, "output.sh")
cat_script = File.join(script_dir, "cat.sh")
malloc_script = File.join(script_dir, "malloc.pl")
env_cmd = "/usr/bin/env"
sleep_cmd = "/bin/sleep"

require 'external_command'
require 'base64'

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

    it "should pass on the existing environment" do
        ENV["FOO"] = "frumious"
        f = ExternalCommand.new(env_cmd).run("Here we are\nThis part will be ignored")
        f.status.should == 0
        f.out.should =~ /^FOO=frumious$/
    end

    it "should be able to set environment variables" do
        env = { "FOO" => "barbie" }
        f = ExternalCommand.new(env_cmd).run("Here we are\nThis part will be ignored", env)
        f.status.should == 0
        f.out.should =~ /^FOO=barbie$/
    end

    it "should be able to override environment variables" do
        ENV["FOO"] = "frumious"
        env = { "FOO" => "barbie" }
        f = ExternalCommand.new(env_cmd).run("Here we are\nThis part will be ignored", env)
        f.status.should == 0
        f.out.should =~ /^FOO=barbie$/
    end

    it "should handle timeouts" do
        start_time = Time.now
        f = ExternalCommand.new(sleep_cmd, "30", :timeout => 2).run
        (Time.now - start_time).should < 5
        f.timed_out.should == true
        f.status.should_not == 0
    end

    it "should be able to run a script which allocates lots of memory" do
        f = ExternalCommand.new(malloc_script).run
        f.status.should == 0
        f.out.should == "OK\n"
        f.err.should == ""
    end

    it "should be able to limit memory available to its children" do
        f = ExternalCommand.new(malloc_script)
        f.memory_limit = 1048576 * 128
        f.run
        f.out.should == ""
        f.err.should == "Out of memory!\n"
    end

    it "should handle data as binary by default" do
        # The base64 string was generated with:
        # printf "hello\360\n" | base64
        string = Base64::decode64('aGVsbG/wCg==')
        args = [cat_script, { :stdin_string => string }]
        f = ExternalCommand.new(*args).run
        f.status.should == 0
        f.out.should == string
        if String.method_defined?(:encode)
            f.out.encoding.to_s.should == 'ASCII-8BIT'
        end
    end

    it 'should encode data with the default encoding if non-binary output is requested' do
        args = [cat_script, { :stdin_string => "Hello\n", :binary_output => false }]
        f = ExternalCommand.new(*args).run
        f.status.should == 0
        f.out.should == "Hello\n"
        if String.method_defined?(:encode)
            f.out.encoding.should == Encoding.default_external
        end
    end

    it "should handle the exit of the program before input is complete" do
        string = "Here we are\nThis part will be ignored" * 40000
        t = ExternalCommand.new(sleep_cmd, "0", :stdin_string => string).run
        t.status.should == 0
        t.err.should == ""
    end

end

