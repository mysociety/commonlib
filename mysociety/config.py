#
# config.py:
# Very simple config parser. Our config files are sort of cod-PHP.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: config.py,v 1.5 2007-10-15 13:48:47 francis Exp $
#

"""
Parse config files (written in a sort of cod-php, using
    define(OPTION_VALUE_NAME, "value of option");
to define individual elements.

Example use:
    mysociety.config.set_file('../conf/general')
    opt = mysociety.config.get('CONFIG_VARIABLE', DEFAULT_VALUE)
"""

import os
import popen2
import re

def find_php():
    """find_php() -> php_binary

       Try to locate the PHP binary in various sensible places.
    """
    path = os.getenv("PATH") or '/bin:/usr/bin';
    paths = path.split(':')
    for dir in path.split(':') + \
        ['/usr/local/bin', '/usr/bin', '/software/bin', '/opt/bin', '/opt/php/bin']:
        for name in ['php4', 'php', 'php4-cgi', 'php-cgi']:
            if os.path.isfile('%s/%s' % (dir, name)):
                return '%s/%s' % (dir,name)
    raise Exception, "unable to locate PHP binary, needed to read config file";

php_path = None
def read_config(f):
    """read_config(FILE) ->

       Read configuration from FILE, which should be the name of a PHP config
       file.  This is parsed by PHP, and any defines are extracted as config
       values. "OPTION_" is removed from any names beginning with that.
    """

    # We need to find the PHP binary.
    global php_path
    if not php_path:
        php_path = find_php()

    # Delete everything from the environment other than our special variable to
    # give PHP the config file name. We don't want PHP to pick up other
    # information from our environment and turn into an FCGI server or
    # something.

    # Just copying os.environ doesn't cause the correct unsetenvs and putenvs
    # to be called, so instead we have to explicitly store it in store_environ
    store_environ = {}
    for k in os.environ.keys():
        store_environ[k] = os.environ[k]
        del os.environ[k]
    os.environ['MYSOCIETY_CONFIG_FILE_PATH'] = f
    child = popen2.Popen3([php_path,], False) # don't capture stderr
    for k,v in store_environ.iteritems():
        os.environ[k] = v

    print >>child.tochild, """
<?php
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
?>"""
    child.tochild.close()

    # skip any header material
    line = True
    while line:
        line = child.fromchild.readline()
        if line == "start_of_options\n":
            break
    else:
        raise Exception, "%s: %s: failed to read options" % (php_path, f)

    # read remainder
    buf = ''.join(child.fromchild.readlines())
    child.fromchild.close()

    # check that php exited successfully
    status = child.wait()
    if os.WIFSIGNALED(status):
        raise Exception, "%s: %s: killed by signal %d" % (php_path, f, os.WTERMSIG(status))
    elif os.WEXITSTATUS(status) != 0:
        raise Exception, "%s: %s: exited with failure status %d" % (php_path, f, os.WEXITSTATUS(status))
    
    # parse out config values
    vals = buf.split('\0'); # option values may be empty
    vals.pop()  # The buffer ends "\0" so there's always a trailing empty value
                # at the end of the buffer. I love perl! Perl is my friend!
                # (I assume this should now read "Python", but I'm not sure.)

    if len(vals) % 2:
        raise Exception, "%s: %s: bad option output from subprocess" % (php_path, f)

    config = {}
    for i in range(len(vals) / 2):
        config[vals[i*2]] = vals[i*2+1]
    config["CONFIG_FILE_NAME"] = f
    return config

main_config_filename = None
def set_file(filename):
    """set_file FILENAME
       Sets the default configuration file, used by mySociety::Config::get.
    """
    
    global main_config_filename
    main_config_filename = filename

cached_configs = {}
def load_default():
    """load_default
       Loads and caches default config file, as set with set_file.  This
       function is implicitly called by get and get_all.
    """

    global main_config_filename, cached_configs

    filename = main_config_filename
    if not filename:
        raise Exception, "Please call mysociety::config::set_file to specify config file" 

    if not filename in cached_configs:
        cached_configs[filename] = read_config(filename)
    return cached_configs[filename]

def get (key, default = None):
    """get KEY [DEFAULT]
       Returns the constants set for KEY from the configuration file specified
       in set_config_file. The file is automatically loaded and cached. An
       exception is thrown if the value isn't present and no DEFAULT is
       specified.
    """

    config = load_default()
    
    if key in config:
        return config[key]
    elif default:
        return default
    else:
        raise Exception, "No value for '%s' in '%s', and no default specified" % (key, config['CONFIG_FILE_NAME'])
