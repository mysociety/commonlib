#
# config.py:
# Very simple config parser.
# Our config files are either YAML or a sort of cod-PHP.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: francis@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: config.py,v 1.14 2010-01-28 00:21:16 duncan Exp $
#

"""
Parse config files.

Traditional mySociety config files are written in a sort of cod-php, using
    define(OPTION_VALUE_NAME, "value of option");
to define individual elements.

This library also supports YAML format: if there is a file that has the
specified name concatenated with ".yml", that will be used in preference.

Example use:
    mysociety.config.set_file('../conf/general')
    opt = mysociety.config.get('CONFIG_VARIABLE', DEFAULT_VALUE)
"""

import os
import subprocess
import yaml

def read_config(f):
    """Read configuration from the specified file.

    If the filename ends in .yml, or FILE.yml exists, that file is parsed as
    a YAML object which is returned. Otherwise FILE is parsed by PHP, and any defines
    are extracted as config values.

    For PHP configuration files only, "OPTION_" is removed from any names
    beginning with that.

    If specified, values from DEFAULTS are merged.
    """
    if f.endswith(".yml"):
        config = read_config_from_yaml(f)
    elif os.path.isfile(f + ".yml"):
        if os.path.exists(f):
            raise Exception("Configuration error: both %s and %s.yml exist (remove one)" % (f, f + ".yml"))
        config = read_config_from_yaml(f + ".yml")
    elif os.path.exists(f):
        config = read_config_from_php(f)
    else:
        raise Exception("Neither %s nor %s.yml can be found" % (f, f + ".yml"))
    
    config["CONFIG_FILE_NAME"] = f
    return config

def read_config_from_yaml(filename):
    fh = open(filename, 'r')
    try:
        try:
            config = yaml.load(fh)
        except ValueError, e:
            raise Exception("Failed to parse YAML: " + e.args[0])
        if not isinstance(config, dict):
            raise Exception("The YAML file must represent an object (a.k.a. hash, dict, map)")
        return config
    finally:
        fh.close()

def find_php():
    """find_php() -> php_binary

       Try to locate the PHP binary in various sensible places.
    """
    path = os.getenv("PATH") or '/bin:/usr/bin'
    paths = path.split(os.pathsep)
    for dir in path.split(os.pathsep) + \
        ['/usr/local/bin', '/usr/bin', '/software/bin', '/opt/bin', '/opt/php/bin']:
        for name in ['php4', 'php', 'php4-cgi', 'php-cgi']:
            if os.name=='nt':
                name += '.exe'
            if os.path.isfile('%s/%s' % (dir, name)):
                return '%s/%s' % (dir,name)
    raise Exception, "unable to locate PHP binary, needed to read config file"

php_path = None
debian_version = None
def read_config_from_php(f):
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

    global debian_version
    if not debian_version:
        try:
            fp = open("/etc/debian_version")
            debian_version = fp.read().strip()
            fp.close()
        except IOError:
            debian_version = 'unknown'

    # Using taskset to deal with debian 5 php/mysql extension bug, 
    # by restricting to one processor
    # but debian 3 doesn't have the necessary function. 
    if debian_version == '3.1':
        args = [php_path]
    else:
        args = ["taskset", "0x1", php_path]
    child = subprocess.Popen(args,
                             stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE) # don't capture stderr
    for k,v in store_environ.iteritems():
        os.environ[k] = v

    print >>child.stdin, """
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
    child.stdin.close()

    # skip any header material
    line = True
    while line:
        line = child.stdout.readline()
        if line == "start_of_options\n":
            break
    else:
        raise Exception, "%s: %s: failed to read options" % (php_path, f)

    # read remainder
    buf = ''.join(child.stdout.readlines())
    child.stdout.close()

    # check that php exited successfully
    status = child.wait()
    if status < 0:
        raise Exception, "%s: %s: killed by signal %d" % (php_path, f, -status)
    elif status > 0:
        raise Exception, "%s: %s: exited with failure status %d" % (php_path, f, status)
    
    # parse out config values
    vals = buf.split('\0'); # option values may be empty
    vals.pop()  # The buffer ends "\0" so there's always a trailing empty value
                # at the end of the buffer. I love perl! Perl is my friend!
                # (I assume this should now read "Python", but I'm not sure.)

    if len(vals) % 2:
        raise Exception, "%s: %s: bad option output from subprocess" % (php_path, f)

    config = {}
    for i in range(len(vals) // 2):
        config[vals[i*2]] = vals[i*2+1]
    return config

main_config_filename = None
def set_file(filename, abspath=True):
    """set_file FILENAME
       Sets the default configuration file, used by mySociety::Config::get.

       By default this will store an absolute path to the file so things
       still work after a change of current working directory. If you really
       want this to be a relative path set the optional argument abspath to
       something false.
    """
    
    global main_config_filename
    main_config_filename = os.path.abspath(filename) if abspath else filename

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
    elif default is not None:
        return default
    else:
        raise Exception("No value for '%s' in '%s', and no default specified" % (key, config['CONFIG_FILE_NAME']))
