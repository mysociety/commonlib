# Run an external command, capturing its stdout and stderr
# streams into variables.
#
# So it’s rather like the `backtick` built-in, except that:
#   - The command is run as-is, rather than being parsed by the shell;
#   - Standard error is also captured.
#
# After the run() method has been called, the instance variables
# out, err and status contain the contents of the process’s stdout,
# the contents of its stderr, and the exit status.
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

class ExternalCommand
    attr_accessor :out, :err
    attr_reader :status

    def initialize(cmd, *args)
        @cmd = cmd
        @args = args

        # Strings to collect stdout and stderr from the child process
        # These may be replaced by the caller, to append to existing strings.
        @out = ""
        @err = ""
        
        # String to collect the grandchild’s exit status from the child.
        @fin = ""
        
        # String to write to the stdin of the child process.
        # This may be set by passing an argument to the run method.
        @in = ""
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
        parent_process

        return self
    end

    private

    def child_process()
        # Reopen stdout and stderr to point at the pipes
        STDOUT.reopen(@out_write)
        STDERR.reopen(@err_write)
        STDIN.reopen(@in_read) if !@in_read.nil?

        # Close all the filehandles other than the ones we intend to use.
        dont_close = [STDOUT, STDERR, @fin_write]
        dont_close.push(STDIN) if !@in_read.nil?
        
        ObjectSpace.each_object(IO) do |fh|
            fh.close unless (
                dont_close.include?(fh) || fh.closed?)
        end
        
        # Override the environment as specified
        ENV.update @env

        # Spawn the grandchild, and wait for it to finish.
        Process::waitpid(fork { grandchild_process })
        
        # Write the grandchild’s exit status to the 'fin' pipe.
        @fin_write.puts($?.exitstatus.to_s)

        exit! 0
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

        while @fin.empty?
           ok = read_and_write_data
           if !ok
               raise "select() timed out even with a nil (infinite) timeout"
            end
        end

        while read_and_write_data(0)
            # Pull out any data that’s left in the pipes
        end

        Process::waitpid(@pid)
        @status = @fin.to_i
        @out_read.close
        @err_read.close
        @in_write.close if !@in_write.nil? && !@in_write.closed?
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
