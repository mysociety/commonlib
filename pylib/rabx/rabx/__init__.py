# Python implementation of RABX string reading/writing.
# Netstrings are documented here: http://cr.yp.to/proto/netstrings.txt

import json
import StringIO
import six
import rabx.error


PROTOCOL_VERSION = '0'


def read(fp, n, thing):
    """Reads N bytes from FP for a THING. Raise an exception if nothing
    returned.

    >>> s = StringIO.StringIO("hello")
    >>> read(s, 3, "first three characters")
    'hel'
    >>> read(s, 2, "last two characters")
    'lo'
    >>> read(s, 3, "non-existent characters")
    Traceback (most recent call last):
    ...
    ProtocolError: EOF reading non-existent characters
    """

    try:
        c = fp.read(n)
    except IOError:
        raise rabx.error.TransportError("Error reading %s" % thing)
    if not c:
        raise rabx.error.ProtocolError("EOF reading %s" % thing)
    return c


def force_bytes(s):
    """Makes sure S is a bytestring.
    >>> force_bytes(123)
    '123'
    >>> force_bytes('caf\xe9')
    'caf\\xe9'
    >>> force_bytes(u'caf\xe9')
    'caf\\xc3\\xa9'
    """
    if isinstance(s, bytes):
        return s
    if isinstance(s, six.string_types):
        return s.encode('utf-8')
    if six.PY3:
        return str(s).encode('utf-8')
    return bytes(s)


def netstring_wr(s, fp):
    """Writes STRING, formatted as a netstring, to FP.
    >>> s = StringIO.StringIO()
    >>> netstring_wr(123, s)
    >>> s.getvalue()
    '3:123,'
    >>> netstring_wr("hello", s)
    >>> s.getvalue()
    '3:123,5:hello,'
    >>> netstring_wr(u"hello", s)
    >>> s.getvalue()
    '3:123,5:hello,5:hello,'
    """
    s = force_bytes(s)
    fp.write('%d:%s,' % (len(s), s))


def netstring_rd(h):
    """Attempts to parse a netstring from HANDLE.
    >>> s = StringIO.StringIO("3:123,5:hello,")
    >>> netstring_rd(s)
    '123'
    >>> netstring_rd(s)
    'hello'
    """
    length = 0
    while True:
        c = read(h, 1, 'netstring length')
        if c == ':':
            break
        try:
            c = int(c)
        except ValueError:
            raise rabx.error.ProtocolError("bad character '%s' in netstring length" % c)
        length = (length * 10) + c

    string = ''
    while (len(string) < length):
        string += read(h, length - len(string), 'netstring content')

    c = read(h, 1, 'netstring trailer')
    if c != ',':
        raise rabx.error.ProtocolError("bad netstring trailer character '%s'" % c)

    return string


def wire_wr(ref, h):
    """Format REF into HANDLE.
    >>> s = StringIO.StringIO()
    >>> wire_wr(123, s)
    >>> s.getvalue()
    'I3:123,'
    >>> wire_wr(u"hello", s)
    >>> s.getvalue()
    'I3:123,T5:hello,'
    >>> wire_wr("hmm", s)
    >>> s.getvalue()
    'I3:123,T5:hello,B3:hmm,'
    >>> wire_wr([1,2,3], s)
    >>> s.getvalue()
    'I3:123,T5:hello,B3:hmm,L1:3,I1:1,I1:2,I1:3,'
    >>> s = StringIO.StringIO()
    >>> wire_wr({'a':1, 'b':[1,2,3]}, s)
    >>> s.getvalue()
    'A1:2,B1:a,I1:1,B1:b,L1:3,I1:1,I1:2,I1:3,'
    """
    if ref is None:
        h.write('N')
    elif isinstance(ref, six.integer_types):
        h.write('I')
        netstring_wr(ref, h)
    elif isinstance(ref, float):
        h.write('R')
        netstring_wr(ref, h)
    elif isinstance(ref, six.text_type):
        h.write('T')
        netstring_wr(ref, h)
    elif isinstance(ref, six.binary_type):
        h.write('B')
        netstring_wr(ref, h)
    elif isinstance(ref, list):
        # Format is L . number of elements . element . element ...
        h.write('L')
        netstring_wr(len(ref), h)
        for i in ref:
            wire_wr(i, h)
    elif isinstance(ref, dict):
        # Format is A . number of keys . key . value . key . value ...
        h.write('A')
        netstring_wr(len(ref), h)
        for i in ref.keys():
            wire_wr(i, h)
            wire_wr(ref[i], h)
    else:
        raise rabx.error.InterfaceError('X cannot be a reference to "%s"' % type(ref))


def wire_rd(h):
    """Parse on-the-wire data from HANDLE and return its representation in perl data structures.
    >>> s = StringIO.StringIO('A1:3,B1:a,I1:1,B1:b,L1:3,I1:1,I1:2,I1:3,B1:c,N,')
    >>> wire_rd(s)
    {'a': 1, 'c': None, 'b': [1, 2, 3]}
    """

    type = read(h, 1, 'type indicator character')

    if type == 'N':
        return None
    elif type == 'I':
        i = netstring_rd(h)
        try:
            return int(i)
        except ValueError:
            raise rabx.error.ProtocolError("data in 'I' string is not a valid integer: '%s'" % i)
    elif type == 'R':
        r = netstring_rd(h)
        try:
            return float(r)
        except ValueError:
            raise rabx.error.ProtocolError("data in 'R' string is not a valid real: '%s'" % r)
    elif type == 'B':
        return netstring_rd(h)
    elif type == 'T':
        t = netstring_rd(h)
        try:
            return t.decode('utf-8')
        except UnicodeDecodeError:
            raise rabx.error.ProtocolError("data in 'T' string are not valid UTF-8 octets: '%s'" % t)
    elif type == 'L':
        len = netstring_rd(h)
        try:
            len = int(len)
        except ValueError:
            raise rabx.error.ProtocolError("bad list length '%s'" % len)
        r = [wire_rd(h) for i in range(len)]
        return r
    elif type == 'A':
        len = netstring_rd(h)
        try:
            len = int(len)
        except ValueError:
            raise rabx.error.ProtocolError("bad associative array length '%s'" % len)
        r = {}
        for i in range(len):
            k = wire_rd(h)
            if k in r:
                raise rabx.error.ProtocolError("repeated element '%s' in associative array" % k)
            v = wire_rd(h)
            r[k] = v
        return r
    else:
        raise rabx.error.ProtocolError("bad type indicator character '%s'" % type)


def call_string(func, args):
    """Return the string used to call FUNCTION with ARGS.
    >>> call_string('function_name', [ 1, 2, 3 ])
    'R1:0,13:function_name,L1:3,I1:1,I1:2,I1:3,'
    """

    if not isinstance(args, list):
        raise rabx.error.InterfaceError('arguments should be reference to list, not %s' % type(args))
    h = StringIO.StringIO()
    h.write('R')
    netstring_wr(PROTOCOL_VERSION, h)
    netstring_wr(func, h)
    wire_wr(args, h)
    return h.getvalue()


def call_string_parse(s):
    """Parse a call string, returning in list context the name of the method called
    and a reference to a list of arguments.
    >>> call_string_parse('R1:0,13:function_name,L1:3,I1:1,I1:2,I1:3,')
    ('function_name', [1, 2, 3])
    """

    h = StringIO.StringIO(s)
    c = read(h, 1, 'call string indicator character')
    if c != 'R':
        raise rabx.error.ProtocolError('first byte of call string should be "R", not "%s"' % c)
    ver = netstring_rd(h)
    if ver != PROTOCOL_VERSION:
        raise rabx.error.ProtocolError('Bad version "%s"' % ver)
    func = netstring_rd(h)
    args = wire_rd(h)
    if not isinstance(args, list):
        raise rabx.error.ProtocolError('function arguments should be list, not %s' % type(args))
    return func, args


def return_string(v):
    """Return the string used to encode a successful function return of VALUE;
    or, an error return in the case where the passed value is of type
    rabx.error.BaseError or a derivative.
    >>> return_string(rabx.error.ProtocolError("hello"))
    'E1:0,3:515,5:hello,'
    >>> return_string({'key': 'value'})
    'S1:0,A1:1,B3:key,B5:value,'
    """
    h = StringIO.StringIO()
    if isinstance(v, rabx.error.BaseError):
        h.write('E')
        netstring_wr(PROTOCOL_VERSION, h)
        netstring_wr(v.value | rabx.error.SERVER, h)  # Indicate that error was detected on server side.
        netstring_wr(v.text, h)
        if hasattr(v, 'extradata'):
            wire_wr(v.extradata, h)
    else:
        h.write('S')
        netstring_wr(PROTOCOL_VERSION, h)
        wire_wr(v, h)
    return h.getvalue()


def return_string_parse(buf):
    """Parse a return string. If it indicates success, return the value; if it
    is an error, raise a corresponding rabx.error.
    >>> return_string_parse('S1:0,A1:1,B3:key,B5:value,')
    {'key': 'value'}
    >>> return_string_parse('E1:0,3:515,5:hello,')
    Traceback (most recent call last):
    ...
    ProtocolError: hello
    """
    h = StringIO.StringIO(buf)
    c = read(h, 1, 'return indicator character')
    if c not in ('E', 'S'):
        raise rabx.error.ProtocolError('first byte of return string should be "S" or "E", not "%s"' % c)
    ver = netstring_rd(h)
    if ver != PROTOCOL_VERSION:
        raise rabx.error.ProtocolError('Bad version "%s"' % ver)

    if c == 'S':
        return wire_rd(h)
    else:
        value = netstring_rd(h)
        text = netstring_rd(h)
        try:
            extra = wire_rd(h)
        except rabx.error.ProtocolError:
            extra = None
        raise rabx.error.ErrorFactory(text, value, extra)


def return_string_json(v):
    """Similar to return_string, only returns JSON rather than netstrings."""
    if isinstance(v, rabx.error.BaseError):
        val = {
            'error_value': v.value | rabx.error.SERVER,  # Indicate that error was detected on server side.
            'error_text': v.text,
        }
        if hasattr(v, 'extradata'):
            val['error_extradata'] = v.extradata
    else:
        val = v
    return json.dumps(v)


def serialise(x):
    """Format X into a string, and return it.
    >>> x = {'key': 'value'}
    >>> serialise(x)
    'A1:1,B3:key,B5:value,'
    """
    h = StringIO.StringIO()
    wire_wr(x, h)
    return h.getvalue()


def unserialise(data):
    """Interpret DATA as RABX on-the-wire data, and return the parsed data.
    >>> x = 'A1:1,B3:key,B5:value,'
    >>> unserialise(x)
    {'key': 'value'}
    """
    h = StringIO.StringIO(data)
    return wire_rd(h)
