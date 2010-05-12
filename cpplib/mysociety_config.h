//
// mysociety_config.h:
// Read the terrible mySociety PHP format config files, as similar code for
// other languages.
//
// Copyright (c) 2010 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org; WWW: http://www.mysociety.org/
//
// $Id: mysociety_error.h,v 1.4 2009-09-24 22:00:29 francis Exp $
//

#include <boost/format.hpp>

#include <iostream>
#include <fstream>

void mysociety_read_conf(const std::string& mysociety_conf_file) {
    setenv("MYSOCIETY_CONFIG_FILE_PATH", mysociety_conf_file.c_str(), 1);

    std::string tmp_php_script = (boost::format("/tmp/c-php-mysociety-conf-%d") % getpid()).str();
    {
        std::ofstream out(tmp_php_script.c_str(), std::ios::out);
        out << 
            "#!/usr/bin/php\n"
            "<?php\n"
            "$b = get_defined_constants();\n"
            "require(getenv(\"MYSOCIETY_CONFIG_FILE_PATH\"));\n"
            "$a = array_diff_assoc(get_defined_constants(), $b);\n"
            "foreach ($a as $k => $v) {\n"
            "    print \"$k=$v\\n\";\n"
            "}\n"
            "?>\n";
    }
    chmod(tmp_php_script.c_str(), 0555);

    FILE * f = popen(tmp_php_script.c_str(), "r");
    if (f == 0) {
        throw Exception("Couldn't open temporary mySociety conf PHP script");
    }
    const int BUFSIZE = 2048;
    char buf[BUFSIZE];
    while(fgets(buf, BUFSIZE,  f)) {
        std::string line = std::string(buf);
        std::string::size_type found = line.find_first_of("=");
        if (found == std::string::npos) {
            throw Exception("config output had line without = in it");
        }
        std::string key = line.substr(0, found);
        std::string value = line.substr(found + 1, line.size() - found - 2);
        // debug_log(boost::format("mySociety config loaded: %s %s") % key % value);

        setenv(key.c_str(), value.c_str(), 1);
    }

    pclose(f); 
}



