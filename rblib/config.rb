# config.rb:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: config.rb,v 1.3 2007-10-24 19:13:07 francis Exp $

module MySociety
    module Config

        # Parse config files (written in a sort of cod-php, using
        #     define(OPTION_VALUE_NAME, "value of option");
        # to define individual elements.
        # 
        # Example use:
        #     MySociety::Config.set_file('../conf/general')
        #     opt = MySociety::Config.get('CONFIG_VARIABLE', DEFAULT_VALUE)


        # find_php() -> php_binary
        # Try to locate the PHP binary in various sensible places.
        def Config.find_php()
            path = ENV["PATH"] or '/bin:/usr/bin'
            paths = path.split(':')
            for dir in path.split(':') +
                ['/usr/local/bin', '/usr/bin', '/software/bin', '/opt/bin', '/opt/php/bin']
                for name in ['php4', 'php', 'php4-cgi', 'php-cgi']
                    if File.exists?(File.join(dir, name))
                        return File.join(dir, name)
                    end
                end
            end
            raise "unable to locate PHP binary, needed to read config file"
        end

        # read_config(FILE) ->
        # Read configuration from FILE, which should be the name of a PHP config
        # file.  This is parsed by PHP, and any defines are extracted as config
        # values. "OPTION_" is removed from any names beginning with that.
        attr :php_path
        def Config.read_config(f)
            # We need to find the PHP binary.
            if @php_path.nil?
                @php_path = find_php()
            end

            # Delete everything from the environment other than our special variable to
            # give PHP the config file name. We don't want PHP to pick up other
            # information from our environment and turn into an FCGI server or
            # something.

            # An assignment or a .clone didn't seem to truly copy ENV
            store_environ = {}
            for k,v in ENV
                store_environ[k] = v
            end
            ENV.clear()
            ENV['MYSOCIETY_CONFIG_FILE_PATH'] = f

            buf = nil
            IO.popen(@php_path, "w+") do |child|
                child.print('''<?php
            $b = get_defined_constants();
            require(getenv("MYSOCIETY_CONFIG_FILE_PATH"));
            $a = array_diff_assoc(get_defined_constants(), $b);
            print "start_of_options\n";
            foreach ($a as $k => $v) {
                print preg_replace("/^OPTION_/", "", $k); /* strip off "OPTION_" if there */
                print "\0";
                print $v;
                print "\0";
            }
            ?>''')
                child.close_write()

                # skip any header material
                line = true
                while line
                    line = child.readline()
                    if line == "start_of_options\n"
                        break
                    else
                        raise "#{@php_path}: #{f}: failed to read options"
                    end
                end

                # read remainder
                buf = child.read()
            end
            ENV.clear()
            ENV.update(store_environ)

            # check that php exited successfully
            if not $?.success?
                raise "#{@php_path}: #{f}: failed status #{$?.to_s}"
            end
            
            # parse out config values
            vals = buf.split(/\0/) # option values may be empty
            if (vals.size % 2) != 0
                raise "#{@php_path}: #{f}: bad option output from subprocess"
            end

            config = {}
            for i in 0..(vals.size / 2 - 1)
                config[vals[i*2]] = vals[i*2+1]
            end
            config["CONFIG_FILE_NAME"] = f
            return config
        end

        # set_file FILENAME [IGNORE_MISSING_FILE]
        # Sets the default configuration file, used by mySociety::Config.get.
        # IGNORE_MISSING_FILE if set means will not error if the file is missing,
        # but instead return default values.
        attr :main_config_filename
        attr :ignore_missing_file
        def Config.set_file(filename, ignore_missing_file = false)
            @main_config_filename = filename
            @ignore_missing_file = ignore_missing_file
        end

        # load_default
        # Loads and caches default config file, as set with set_file.  This
        # function is implicitly called by get and get_all.
        attr :cached_configs
        def Config.load_default()
            filename = @main_config_filename
            if not filename
                raise "Please call MySociety::Config.set_file to specify config file" 
            end
            if not File.exists?(filename)
                if @ignore_missing_file
                    return {"CONFIG_FILE_NAME" => filename + " (missing file)"}
                else
                    raise "File missing '" + filename + "'"
                end
            end

            if @cached_configs.nil?
                @cached_configs = {}
            end
            if not @cached_configs.include?(filename)
                @cached_configs[filename] = read_config(filename)
            end
            return @cached_configs[filename]
        end

        # get KEY [DEFAULT]
        # Returns the constants set for KEY from the configuration file specified
        # in set_config_file. The file is automatically loaded and cached. An
        # exception is thrown if the value isn't present and no DEFAULT is
        # specified.
        def Config.get (key, default = nil)
            config = load_default()
            
            if config.include?(key)
                return config[key]
            elsif not default.nil?
                return default
            else
                raise "No value for '#{key}' in '#{config['CONFIG_FILE_NAME']}', and no default specified" 
            end
        end

        # getbool KEY [DEFAULT]
        # Returns the constants for the give KEY, defaulting to DEFAULT,
        # and casts it from 1 / 0 to true or false. This is needed as, unlike
        # PHP, Perl and Python for which the config format was initially used,
        # Ruby treats 0 as true.
        def Config.getbool (key, default = nil)
            if default == false
                default = 0
            elsif default == true
                default = 1
            end
            return get(key, default).to_i > 0
        end
    end
end

