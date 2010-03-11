//
// mysociety_error.cpp:
// Some helpers.
//
// Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org; WWW: http://www.mysociety.org/
//
// $Id: mysociety_error.h,v 1.4 2009-09-24 22:00:29 francis Exp $
//

#include <string>

#if defined(OUTPUT_ROUTE_DETAILS) or defined(DEBUG)
#include <boost/format.hpp>
#endif

#include <stdio.h>
#include <assert.h>
/*#include <unwind.h>
#include <dlfcn.h>*/

/* Logging and debug assertions. Use assert for assertion that matter in release mode,
 * debug_assert for ones that can be stripped. */
#ifdef DEBUG
    void do_log(boost::basic_format<char, std::char_traits<char>, std::allocator<char> > &bf) {
        puts(("DEBUG: " + bf.str()).c_str());
    }
    void do_log(const std::string& str) {
        puts(("DEBUG: " + str).c_str());
    }
    #define debug_log(message) do_log(message);
    #define debug_assert(thing) assert(thing);
#else
    #define debug_log(message) while(0) { };
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

// Taken from http://gcc.gnu.org/bugzilla/show_bug.cgi?id=33903#c5
// XXX can't get it to work
/*std::string mysociety_last_exception_stacktrace;
_Unwind_Reason_Code helper( struct _Unwind_Context* ctx, void* ) {
    void* p = reinterpret_cast< void* >( _Unwind_GetIP( ctx ) );
    Dl_info info;
    if ( dladdr( p, &info ) ) {
        if ( info.dli_saddr ) {
            long d = reinterpret_cast< long >( p )
                    - reinterpret_cast< long >( info.dli_saddr );
            std::string line = (boost::format("%p %s+0x%lx\n") % p % info.dli_sname % d).str();
            fprintf(stderr, line.c_str());
            mysociety_last_exception_stacktrace += line;
        }
    }
    return _URC_NO_REASON;
}

extern "C" void __real___cxa_throw( void* thrown_exception,
        std::type_info* tinfo, void ( *dest )( void* ) )
        __attribute__(( noreturn ));

extern "C" void __wrap___cxa_throw( void* thrown_exception,
        std::type_info* tinfo, void ( *dest )( void* ) )
{
        _Unwind_Backtrace( helper, 0 );
        __real___cxa_throw( thrown_exception, tinfo, dest );
}

Needs these GCC compile flags:
-Wl,--wrap,__cxa_throw -ldl -rdynamic
*/
