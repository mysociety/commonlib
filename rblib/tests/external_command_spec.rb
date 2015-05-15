# -*- encoding : utf-8 -*-
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
        t = ExternalCommand.new(true_script).run
        t.status.should == 0
        t.out.should == ""
        t.err.should == ""
    end

    it "should get correct status code for false.sh" do
        f = ExternalCommand.new(false_script).run
        f.status.should == 1
        f.out.should == ""
        f.err.should == ""
    end

    it "should get stdout and stderr" do
        f = ExternalCommand.new(output_script, "out", "err", "10", "23").run
        f.status.should == 23
        f.out.should == (0..9).map {|i| "out #{i}\n"}.join("")
        f.err.should == (0..9).map {|i| "err #{i}\n"}.join("")
    end

    it "should work with large amounts of data" do
        f = ExternalCommand.new(output_script, "a longer output line", "a longer error line", "10000", "5").run
        f.status.should == 5
        f.out.should == (0..9999).map {|i| "a longer output line #{i}\n"}.join("")
        f.err.should == (0..9999).map {|i| "a longer error line #{i}\n"}.join("")
    end

    it "should handle stdin" do
        args = [cat_script, { :stdin_string => "Here we are\nThis part will be ignored" }]
        f = ExternalCommand.new(*args).run
        f.status.should == 0
        f.out.should == "Here we are\n"
    end

    it "should pass on the existing environment" do
        ENV["FOO"] = "frumious"
        args = [env_cmd, { :stdin_string => "Here we are\nThis part will be ignored" }]
        f = ExternalCommand.new(*args).run
        f.status.should == 0
        f.out.should =~ /^FOO=frumious$/
    end

    it "should be able to set environment variables" do
        args = [env_cmd, { :stdin_string => "Here we are\nThis part will be ignored",
                           :env => { "FOO" => "barbie" } }]
        f = ExternalCommand.new(*args).run
        f.status.should == 0
        f.out.should =~ /^FOO=barbie$/
    end

    it "should be able to override environment variables" do
        ENV["FOO"] = "frumious"
        args = [env_cmd, { :stdin_string => "Here we are\nThis part will be ignored",
                           :env => { "FOO" => "barbie" } }]
        f = ExternalCommand.new(*args).run
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
        f = ExternalCommand.new(malloc_script, :memory_limit => 1048576 * 128).run
        f.out.should == ""
        f.err.should == "Out of memory!\n"
    end

    it "should not limit the memory available to calling code" do
        f = ExternalCommand.new(malloc_script, :memory_limit => 1048576 * 128)
        allocated_memory = Process.getrlimit(Process::RLIMIT_AS)[0].to_i
        f.run
        current_memory = Process.getrlimit(Process::RLIMIT_AS)[0]
        current_memory.should == allocated_memory
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

    it 'should raise a ChildUnterminated exception if the process cannot be terminated' do
        start_time = Time.now
        external_command = ExternalCommand.new(sleep_cmd, "30", :timeout => 2)
        external_command.stub!(:try_to_kill).and_return(false)
        lambda { f = external_command.run }.should raise_error(ExternalCommand::ChildUnterminated)
        (Time.now - start_time).should < 5
        external_command.timed_out.should == true
        external_command.status.should_not == 0
    end

end

