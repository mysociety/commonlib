# -*- encoding : utf-8 -*-
# Run an external command, capturing its stdout and stderr streams into
# variables, and returning some information about the way the process
# exited.

#
# After the run method has been called, the attributes
# out, err, and status contain the contents of the process's
# stdout, the contents of its stderr, and the exit status.  The instance
# variable exited is true if the process exited normally, and false
# otherwise (usually indicating a crash or timeout). The instance
# variable timed_out indicates that this code forced the process to
# finish.
#
# Example usage:
#   require 'external_command'
#   xc = ExternalCommand("ls", "-l").run
#   puts "Ran ls -l with exit status #{xc.status}"
#   puts "===STDOUT===\n#{xc.out}"
#   puts "===STDERR===\n#{xc.err}"



require 'open4'
class ExternalCommand

    class ChildUnterminated < StandardError
    end

    attr_reader :status,
                :timed_out,
                :exited,
                :binary_output,
                :binary_input,
                :memory_limit,
                :err,
                :out,
                :env

    # Final argument can be a hash of options.
    # Valid options are:
    # :append_to - string to append the output of the process to
    # :append_errors_to - string to append the errors produced by the process to
    # :stdin_string - stdin string to pass to the process
    # :binary_output - boolean flag for treating the output as binary or text encoded with
    #                   the default external encoding
    # :binary_input - boolean flag for treating the input as binary or as text encoded with
    #                   the default external encoding
    # :memory_limit - maximum amount of memory (in bytes) available to the process
    # :timeout - maximum amount of time (in s) to allow the process to run for
    # :env - hash of environment variables to set for the process
    def initialize(cmd, *args)
        if !args.empty? && args.last.is_a?(Hash)
            options = args.pop
        else
            options = {}
        end
        @cmd = cmd
        @args = args
        @timeout = options.fetch(:timeout, nil)

        # Strings to collect stdout and stderr from the child process
        # These may be replaced by the caller, to append to existing strings.
        @out = options.fetch(:append_to, "")
        @err = options.fetch(:append_errors_to, "")

        # Stdin string to pass to the process
        @in = options.fetch(:stdin_string, nil)

        # By default, the strings returned for stdout and sterr will
        # be treated as binary, so will have the encoding ASCII-8BIT.
        # Set binary_mode to false in order to have strings transcoded
        # using the default internal and external encodings.
        @binary_output =  options.fetch(:binary_output, true)
        @binary_input = options.fetch(:binary_input, true)

        # Memory limit available to this process. We will use this as the
        # hard limit for the child process and then restore it once the 
        # child process has run.
        @default_memory_limit =  Process.getrlimit(Process::RLIMIT_AS)[0]
 
        # Maximum memory available to the child process (in bytes) before
        # it is killed by the kernel. 
        @memory_limit = options.fetch(:memory_limit) { @default_memory_limit }

        # Hash of environment variables to set for the process
        @env = options.fetch(:env, {})

    end

    def run

        if @memory_limit < Process.getrlimit(Process::RLIMIT_AS)[0]
            Process.setrlimit(Process::RLIMIT_AS, @memory_limit, @default_memory_limit)
        end

        # Store current environment variables before being overridden
        old_env_values = @env.keys.inject({}) { |m, k| m[k] = ENV[k]; m }

        # Override the environment as specified
        ENV.update @env

        begin
            status = Open4::popen4(@cmd, *@args) do |pid, stdin, stdout, stderr|

                # IOStreams should handle ASCII-8BIT encoded strings when told to
                # expect binary data
                stdout.binmode if binary_output
                stdin.binmode if binary_input

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
            
        ensure

            # Restore the original memory limit
            Process.setrlimit(Process::RLIMIT_AS, @default_memory_limit)
        end

        # Reset overridden environment variables
        ENV.update(old_env_values)

        # if we're not expecting binary output, convert the output streams to the
        # default encoding now they are written to - not before, as there might be
        # partial characters there
        unless binary_output
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
        unterminated = false
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
                        if !try_to_kill("KILL", pid)
                            unterminated = true
                        end
                    end
                end
                # Collect any final output already in the buffers
                read_and_write(0)
                @exited = false
                @timed_out = true
                if unterminated
                    raise ChildUnterminated, %Q[External Command: Process #{pid} executing "#{@cmd}" timed out at #{@timeout}s but could not be terminated.]
                end
                return
            end
        end
    end

end
