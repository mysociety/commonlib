//
// mysociety_error.cpp:
// Some helpers.
//
// Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org; WWW: http://www.mysociety.org/
//
// $Id: mysociety_error.h,v 1.3 2009-04-14 16:13:38 francis Exp $
//

#include <string>

#if defined(OUTPUT_ROUTE_DETAILS) or defined(DEBUG)
#include <boost/format.hpp>
#endif

#include <stdio.h>
#include <assert.h>

/* Logging and debug assertions. Use assert for assertion that matter in release mode,
 * debug_assert for ones that can be stripped. */
#ifdef DEBUG
    void do_log(boost::basic_format<char, std::char_traits<char>, std::allocator<char> > &bf) {
        puts(("DEBUG: " + bf.str()).c_str());
    }
    void do_log(const std::string& str) {
        puts(("DEBUG: " + str).c_str());
    }
    #define log(message) do_log(message);
    #define debug_assert(thing) assert(thing);
#else
    #define log(message) while(0) { };
    #define debug_assert(thing) while(0) { };
#endif

/* Most similar to Python's Exception */
class Exception : public std::exception
{
    std::string s;
public:
    Exception(std::string s_) : s("Exception: " + s_) { }
    ~Exception() throw() { }
    const char* what() const throw() { return s.c_str(); }
};

/* Error handling version of fread */
void my_fread ( void * ptr, size_t size, size_t count, FILE * stream ) {
    size_t ret = fread(ptr, size, count, stream);
    assert(ret == count);
}

/* Error handling version of fwrite */
void my_fwrite ( const void * ptr, size_t size, size_t count, FILE * stream ) {
    size_t ret = fwrite(ptr, size, count, stream);
    assert(ret == count);
}

