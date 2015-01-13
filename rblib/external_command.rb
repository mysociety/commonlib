# encoding: utf-8
# Run an external command, capturing its stdout and stderr streams into
# variables, and returning some information about the way the process
# exited.

#
# After the run() method has been called, the instance variables
# out, err, and status contain the contents of the process<E2><80><99>s
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

# <rant author="robin">
#   In any sane language, this would be implemented with a
#   single child process. The parent process would block on
#   select(), and when the child process terminated, the
#   select call would be interrupted by a CHLD signal
#   and return EINTR. Unfortunately Ruby goes out of its
#   way to prevent this from working, automatically restarting
#   the select call if EINTR is returned. Therefore we
#   use a parent-child-grandchild arrangement, where the
#   parent blocks on select() and the child blocks on
#   waitpid(). When the child detects that the grandchild
#   has finished, it writes to a pipe that’s included in
#   the parent’s select() for this purpose.
# </rant>

require 'fcntl'

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

        # String to collect the grandchild’s exit status from the child.
        @fin = ""

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
        @memory_limit = Process.getrlimit(Process::RLIMIT_AS)[0]
    end

    def run(stdin_string=nil, env={})
        # Pipes for parent-child communication
        @out_read, @out_write = IO::pipe
        @err_read, @err_write = IO::pipe
        @fin_read, @fin_write = IO::pipe
        if !stdin_string.nil?
            @in_read, @in_write = IO::pipe
            @in = stdin_string.dup
        else
            @in_read, @in_write = nil, nil
        end
        @env = env

        @pid = fork do
            # Here we’re in the child process.
            child_process
        end

        # Here we’re in the parent process.
        @timed_out = parent_process

        return self
    end

    private

    def child_process()
        # If you ever need to print debugging information,
        # uncomment the following line, add original_out
        # to the dont_close array below, then you can use
        # original_out.puts to print messages to the original
        # stdout.
        # original_out = IO.new STDOUT.fcntl Fcntl::F_DUPFD

        # Reopen stdout and stderr to point at the pipes
        STDOUT.reopen(@out_write)
        STDERR.reopen(@err_write)
        STDIN.reopen(@in_read) if !@in_read.nil?

        # Close all the filehandles other than the ones we intend to use.
        dont_close = [STDOUT, STDERR, @fin_write]
        dont_close.push(STDIN) if !@in_read.nil?

        ObjectSpace.each_object(IO) do |fh|
            begin
                fh.close unless dont_close.include?(fh)
            rescue => e
                # Perhaps it is already closed, or closing it
                # would raise an "unitialized stream" exception
            end
        end

        # Override the environment as specified
        ENV.update @env

        # Set resource limits (if we can)
        if @memory_limit < Process.getrlimit(Process::RLIMIT_AS)[0]
            Process.setrlimit(Process::RLIMIT_AS, @memory_limit)
        end

        # Spawn the grandchild, and wait for it to finish.
        Process::waitpid(fork { grandchild_process })

        # Write the grandchild’s exit status to the 'fin' pipe,
        # or the special value 256 to indicate an abnormal exit.
        if !$?.exited?
            @fin_write.puts('256')
        else
            @fin_write.puts($?.exitstatus.to_s)
        end

        exit! 0
    end

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

    def grandchild_process()
        exec(@cmd, *@args)

        # This is only reached if the exec fails
        @err_write.print("Failed to exec: #{[@cmd, *@args].join(' ')}")
        exit! 99
    end

    def parent_process()
        # Close the writing ends of the pipes
        @out_write.close
        @err_write.close
        @fin_write.close
        @in_read.close if !@in_read.nil?

        @fhs_read = {@out_read => @out, @err_read => @err, @fin_read => @fin}
        @fhs_write = {}
        if !@in_write.nil?
            @fhs_write[@in_write] = @in
        end

        if @timeout.nil?
            while @fin.empty?
               ok = read_and_write_data
               if !ok
                   raise "select() timed out even with a nil (infinite) timeout"
                end
            end
        else
            time_to_give_up = Time.now.to_f + @timeout
            while @fin.empty?
                remaining_time = time_to_give_up - Time.now.to_f
                ok = remaining_time > 0 && read_and_write_data(remaining_time)
                if !ok
                    # Timed out

                    # Try to kill the process gently
                    if !try_to_kill("TERM", @pid)
                        # If that fails, wait a second and try again
                        sleep 1
                        if !try_to_kill("TERM", @pid)
                            # If THAT fails, terminate with extreme prejudice
                            try_to_kill("KILL", @pid)
                            # (If even that fails, we’re out of luck. Carry on.)
                        end
                    end
                    @status = 1
                    @exited = false
                    return true
                end
            end
        end

        while read_and_write_data(0)
            # Pull out any data that’s left in the pipes
        end

        Process::waitpid(@pid)
        @status = @fin.to_i
        @exited = !(@fin.to_i == 256)

        # Transcode strings as if they were retrieved using default
        # internal and external encodings
        if RUBY_VERSION.to_f >= 1.9 && ! binary_mode
            outstreams = { @out_read => @out, @err_read => @err }
            outstreams.keys.each do |io|
                outstreams[io].force_encoding(io.external_encoding)
                outstreams[io].encode(Encoding.default_internal)
            end
        end
        @out_read.close
        @err_read.close
        @in_write.close if !@in_write.nil? && !@in_write.closed?
        return false
    end

    def read_and_write_data(timeout=nil)
        #puts "select(#{@fhs_read.keys.inspect}, #{@fhs_write.keys.inspect})"
        ready_array = IO.select(@fhs_read.keys, @fhs_write.keys, [], timeout)
        return false if ready_array.nil?
        ready_array[0].each do |fh|
            begin
                s = fh.readpartial(8192)
                #puts "<<[#{fh}] #{s}"
                @fhs_read[fh] << s
            rescue EOFError
                #puts "! EOF reading from #{fh}"
                @fhs_read.delete fh
            end
        end
        ready_array[1].each do |fh|
            begin
                s = @fhs_write[fh]
                #puts ">>[#{fh}] #{s}"
                n = fh.syswrite(s)
                s.slice!(0, n)
                if s.empty?
                    fh.close
                    @fhs_write.delete fh
                end
            rescue Errno::EPIPE
                fh.close
                @fhs_write.delete fh
            end
        end
        return true
    end
end
