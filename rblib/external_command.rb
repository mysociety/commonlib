# encoding: utf-8
# Run an external command, capturing its stdout and stderr streams into
# variables, and returning some information about the way the process
# exited.

#
# After the run() method has been called, the attributes
# out, err, and status contain the contents of the process's
# stdout, the contents of its stderr, and the exit status.  The instance
# variable exited is true if the process exited normally, and false
# otherwise (usually indicating a crash or timeout). The instance
# variable timed_out indicates that this code forced the process to
# finish.
#
# Example usage:
#   require 'external_command'
#   xc = ExternalCommand("ls", "-l").run()
#   puts "Ran ls -l with exit status #{xc.status}"
#   puts "===STDOUT===\n#{xc.out}"
#   puts "===STDERR===\n#{xc.err}"
#
# The out and err attributes are writeable. If you assign
# a string, after calling the constructor and before calling
# run(), then the subprocess output/error will be appended
# to this string.

require 'open4'
class ExternalCommand
    attr_accessor :out, :err, :binary_mode, :memory_limit
    attr_reader :status
    attr_reader :timed_out
    attr_reader :exited

    # Final argument can be a hash of options.
    # Valid options are:
    # :timeout - maximum amount of time (in s) to allow the process to run for
    def initialize(cmd, *args)
        if !args.empty? && args[-1].is_a?(Hash)
            options = args.pop
        else
            options = {}
        end

        @cmd = cmd
        @args = args
        @timeout = options[:timeout]

        # Strings to collect stdout and stderr from the child process
        # These may be replaced by the caller, to append to existing strings.
        @out = ""
        @err = ""

        # String to write to the stdin of the child process.
        # This may be set by passing an argument to the run method.
        @in = ""

        # By default, the strings returned for stdout and sterr will
        # be treated as binary, so will have the encoding ASCII-8BIT.
        # Set binary_mode to false in order to have strings transcoded
        # in Ruby 1.9 using the default internal and external encodings.
        @binary_mode = true

        # Maximum memory available to the child process (in bytes) before
        # it is killed by the kernel.  This value is used as both the soft
        # and hard limit.

        @memory_limit = options.fetch(:memory_limit) { Process.getrlimit(Process::RLIMIT_AS)[0] }
    end

    def run(stdin_string=nil, env={})

        if @memory_limit < Process.getrlimit(Process::RLIMIT_AS)[0]
            Process.setrlimit(Process::RLIMIT_AS, @memory_limit)
        end

        # Override the environment as specified
        ENV.update @env

        status = Open4::popen4(@cmd, *@args) do |pid, stdin, stdout, stderr|

            # IOStreams should handle ASCII-8BIT encoded strings when told to
            # expect binary data
            if RUBY_VERSION.to_f >= 1.9 && binary_mode
                stdout.binmode
                stdin.binmode
            end


            if @in
                @instreams = { stdin => @in.dup }
            else
                @instreams = {}
                stdin.close
            end
            @outstreams = { stdout => @out, stderr => @err }

            if @timeout
                read_and_write_with_terminate_on_timeout(pid)
                return self if @timed_out
            else
                read_and_write while @outstreams.any?
            end

        end
        # if we're not expecting binary output, convert the output streams to the
        # default encoding now they are written to - not before, as there might be
        # partial characters there
        if RUBY_VERSION.to_f >= 1.9 && ! binary_mode
            [ @out, @err ].each { |io| io.force_encoding(Encoding.default_external) }
        end
        @exited = status.exited?
        @status = status.exitstatus
        self
    end

    private

    # Try to kill the process with pid
    # Returns true on successful kill, false otherwise
    def try_to_kill(signal, pid)
        begin
            Process.kill(signal, pid)
        rescue Errno::ESRCH
            # already dead
            return true
        end
        sleep 0.1
        begin
            exit_status = Process.waitpid(pid, Process::WNOHANG)
        rescue Errno::ECHILD
            # already dead – not ordinarily possible unless we’re ignoring SIGCHLD
            return true
        end
        return !exit_status.nil?
    end

    # Read a chunk of data from one of of the external process's output streams. Closes
    # a stream and deletes it from the array of output streams when there is no more
    # data to read.
    def read_from_stream(io_stream)
        if io_stream.eof?
            io_stream.close
            @outstreams.delete io_stream
        else
            # 8kb - usually a reasonable buffer size
            data = io_stream.readpartial(8192)
            @outstreams[io_stream] << data
        end
    end

    # Write a chunk of data to the external process's input stream.  Closes
    # a stream and deletes it from the array of input streams when there is no more
    # data to write. Does the same on disconnection of the stream, indicated by
    # EPIPE.
    def write_to_stream(io_stream)
        begin
            input_string = @instreams[io_stream]
            number_of_bytes_written = io_stream.syswrite(input_string)
            input_string.slice!(0, number_of_bytes_written)
            if input_string.empty?
                io_stream.close
                @instreams.delete io_stream
            end
        rescue Errno::EPIPE
            io_stream.close
            @instreams.delete io_stream
        end
    end

    # reads and writes data to the process's streams. If a timeout is passed,
    # returns false if nothing can be read or written within that timeout.
    def read_and_write(timeout=nil)
        ready = IO.select(@outstreams.keys, @instreams.keys, [], timeout)
        return false if ready.nil?
        ready[0].each{ |io_stream| read_from_stream(io_stream) }
        ready[1].each{ |io_stream| write_to_stream(io_stream) }
    end

    def read_and_write_with_terminate_on_timeout(pid)
        time_to_give_up = Time.now.to_f + @timeout
        while @outstreams.any?
            remaining_time = time_to_give_up - Time.now.to_f
            # check that we still have time remaining and that the select
            # call does not time out in that time
            ok = remaining_time > 0 && read_and_write(remaining_time)

            if !ok
                # Try to kill the process gently
                if !try_to_kill("TERM", pid)
                    # If that fails, wait a second and try again
                    sleep 1
                    if !try_to_kill("TERM", pid)
                        # If THAT fails, terminate with extreme prejudice
                        try_to_kill("KILL", pid)
                        # (If even that fails, we’re out of luck. Carry on.)
                    end
                end
                # Collect any final output already in the buffers
                read_and_write(0)
                @exited = false
                @timed_out = true
                return
            end
        end
    end

end
