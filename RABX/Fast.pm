#!/usr/bin/perl -w
#
# RABX/Fast.pm:
# Fast (C) serialisation code.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: team@mysociety.org; WWW: http://www.mysociety.org/
#

package RABX::Fast;

my $rcsid = ''; $rcsid .= '$Id: Fast.pm,v 1.6 2009-01-26 14:21:51 matthew Exp $';

use strict;

use Inline C => Config => CCFLAGS => '-g -Wall';

use Inline C => <<'EOF';

#define PROTOCOL_VERSION    "0"

/* netstring_append STRING NUM BUFFER OFFSET LENGTH
 * Append the NUM-byte STRING as a netstring to BUFFER beginning at location
 * *OFFSET. BUFFER should be allocated with malloc; *LENGTH is its allocated
 * length. If BUFFER is too short for the new string, grows BUFFER with
 * realloc, updating *LENGTH and returning the new BUFFER. */
static unsigned char *netstring_append(const char *s, size_t L, unsigned char *buf, size_t *off, size_t *len) {
    char l[32];
    size_t Ll;
    Ll = sprintf(l, "%u:", (unsigned)L);
    if (*off + Ll + L + 1 > *len)
        buf = realloc(buf, *len += Ll + L + 1);
    memcpy(buf + *off, l, Ll);
    *off += Ll;
    memcpy(buf + *off, s, L);
    *off += L;
    buf[(*off)++] = ',';
    return buf;
}

/* serialise X BUFFER OFFSET LENGTH
 * Serialise the data structure in X into BUFFER, beginning at offset *OFFSET.
 * *LEN gives the total length of BUFFER. Returns BUFFER (perhaps reallocated)
 * on success, and updates *OFFSET (and perhaps *LENGTH). Croaks on error. */
unsigned char *serialise(SV *x, unsigned char *buf, size_t *off, size_t *len) {
    char b[128];
    size_t n;

    if (*off + 16 > *len)
        buf = realloc(buf, *len += 16);

    if (!SvOK(x))
        /* Not defined; interpret as null. */
        buf[(*off)++] = 'N';
    else if (!SvROK(x)) {
        /* Scalar. */
        char *B;
        STRLEN l;
        /* Scalar. Format as appropriate. */
        if (SvIOK(x)) {
            n = snprintf(b, sizeof b, "%d", (int)SvIV(x));
            buf[(*off)++] = 'I';
            buf = netstring_append(b, n, buf, off, len);
        } else if (SvNOK(x)) {
            n = snprintf(b, sizeof b, "%lf", SvNV(x));
            buf[(*off)++] = 'R';
            buf = netstring_append(b, n, buf, off, len);
        } else if (SvUTF8(x)) {
            buf[(*off)++] = 'T';
            B = SvPV(x, l); /* ...bytes? */
            buf = netstring_append(B, l, buf, off, len);
        } else {
            buf[(*off)++] = 'B';
            B = SvPV(x, l);
            buf = netstring_append(B, l, buf, off, len);
        }
    } else {
        /* Some kind of reference. */
        I32 i, N;
        SV *y;
        HE *ent;
        y = SvRV(x);
        switch (SvTYPE(y)) {
            case SVt_PVAV:
                /* List. */
                buf[(*off)++] = 'L';
                N = av_len((AV*)y) + 1;
                n = snprintf(b, sizeof b, "%d", (int)N);
                buf = netstring_append(b, n, buf, off, len);
                for (i = 0; i < N; ++i) {
                    SV **z;
                    z = av_fetch((AV*)y, (I32)i, 0);
                    buf = serialise(z ? *z : &PL_sv_undef, buf, off, len);
                }
                break;

            case SVt_PVHV:
                /* Hash. */
                buf[(*off)++] = 'A';
                n = snprintf(b, sizeof b, "%d", (int)(N = hv_iterinit((HV*)y)));
                buf = netstring_append(b, n, buf, off, len);
                while ((ent = hv_iternext((HV*)y))) {
                    SV *k, *v;
                    k = hv_iterkeysv(ent);
                    buf = serialise(k, buf, off, len);
                    v = hv_iterval((HV*)y, ent);
                    buf = serialise(v, buf, off, len);
                }
                break;

            default:
                croak("only pass references to HASH or ARRAY");
                break;
        }
    }

    return buf;
}

/* do_serialise X
 * Return the serialised form of X. */
SV *do_serialise(SV *x) {
    SV *ret;
    char *buf;
    size_t off = 0, len;
    buf = malloc(len = 64);
    buf = serialise(x, buf, &off, &len);
    ret = newSVpvn(realloc(buf, off), off);
    return ret;
}

/* netstring_parse BUFFER OFFSET LENGTH NUM
 * Parse a netstring from BUFFER, beginning at *OFFSET. LENGTH is the total
 * length of BUFFER in bytes. Updates *OFFSET and returns the parsed string,
 * and if NUM is non-null, saves its length in *NUM. Croaks on error. */
char *netstring_parse(const unsigned char *buf, size_t *off, const size_t len, size_t *rlen) {
    static char *ret;
    static size_t retlen;
    size_t N = 0;
    do {
        if (*off >= len)
            croak("not enough space for netstring length");
        if (!strchr("0123456789", buf[*off]))
            croak("bad character in netstring length");
        N = (N * 10) + (buf[*off] - '0');
        (*off)++;
    } while (buf[*off] != ':');
    (*off)++;
    if (*off + N + 1 > len)
        croak("not enough space for netstring data");
    else if (buf[*off + N] != ',')
        croak("bad netstring trailer character");
    if (!ret || retlen < N + 1)
        ret = realloc(ret, retlen = N + 1);
    ret[N] = 0; /* ensure null-termination */
    memcpy(ret, buf + *off, N);
    *off += N + 1;
    if (rlen) *rlen = N;
    return ret;
}

/* do_netstring_parse S
 * Parse S, returning a scalar. */
SV *do_netstring_parse(SV *b) {
    size_t off = 0, len, sl;
    STRLEN l;
    unsigned char *buf;
    char *s;
    buf = (unsigned char*)SvPV(b, l);
    len = l;
    s = netstring_parse(buf, &off, len, &sl);
    l = (STRLEN)sl;
    return newSVpv(s, l);
}

/* unserialise BUFFER OFFSET LENGTH
 * Parse serialised data beginning at *OFFSET in BUFFER. LENGTH is the total
 * length of BUFFER. Returns the parsed data and updates *OFFSET. Croaks on
 * error. */
SV *unserialise(const unsigned char *buf, size_t *off, const size_t len) {
    SV *ret;
    int c;
    if (*off >= len)
        croak("not enough space for serialised data");
    c = (char)buf[(*off)++];
    if (c == 'N')
        ret = &PL_sv_undef;
    else if (c == 'I' || c == 'R') {
        char *n;
        int i, l;
        double r;
        n = netstring_parse(buf, off, len, NULL);
        l = (c == 'I' ? sscanf(n, "%d", &i) : sscanf(n, "%lf", &r));
        if (l == 0)
            /* XXX we don't check for data after the first NUL */
            croak("bad value in numeric type");
        ret = (c == 'I' ? newSViv((IV)i) : newSVnv((NV)r));
    } else if (c == 'T' || c == 'B') {
        char *s;
        size_t l;
        STRLEN sl;
        s = netstring_parse(buf, off, len, &l);
        sl = (STRLEN)l;
        ret = newSVpv(s, sl);
        if (c == 'T') {
            if (!is_utf8_string((U8*)s, sl))
                croak("text value is not UTF-8");
            SvUTF8_on(ret);
        } else
            SvUTF8_off(ret);
    } else if (c == 'L' || c == 'A') {
        AV *array;
        HV *hash;
        char *n;
        int i, j, l;
        n = netstring_parse(buf, off, len, NULL);
        l = sscanf(n, "%d", &i);
        if (l == 0)
            /* XXX we don't check for data after the first NUL */
            croak("bad value in list/array length");
        if (c == 'L')
            array = newAV();
        else
            hash = newHV();
        for (j = 0; j < i; ++j) {
            SV *k;
            k = unserialise(buf, off, len);
            if (c == 'L')
                av_push(array, k);
            else {
                SV *v;
                v = unserialise(buf, off, len);
                hv_store_ent(hash, k, v, 0);
            }
        }

        if (c == 'L')
            ret = newRV_noinc((SV*)array);
        else
            ret = newRV_noinc((SV*)hash);
    } else {
        croak("bad type indicator character");
    }
    return ret;
}

/* do_unserialise S
 * Read serialised data from S and return its perl form. */
SV *do_unserialise(SV *b) {
    size_t off = 0, len;
    STRLEN l;
    unsigned char *buf;
    buf = (unsigned char*)SvPVbyte(b, l);
    len = l;
    return unserialise(buf, &off, len);
}

/* do_call_string_parse S
 * Parse a call string from S, returning in list context the name of the
 * function called and its arguments. */
void do_call_string_parse(SV *b) {
    size_t off = 0, len, fl;
    STRLEN l;
    char *version, *s;
    SV *funcname, *args;
    unsigned char *buf;
    Inline_Stack_Vars;
    
    buf = (unsigned char*)SvPVbyte(b, l);
    len = l;
    if (len < 4)
        croak("not long enough to be a call string");
    else if (buf[off] != 'R')
        croak("bad call string indicator");
    ++off;
    version = netstring_parse(buf, &off, len, NULL);
    if (strcmp(version, "0"))
        croak("bad call string version");
    s = netstring_parse(buf, &off, len, &fl);
    l = (STRLEN)fl;
    funcname = newSVpv(s, l);
    args = unserialise(buf, &off, len);
    
    Inline_Stack_Reset;
    Inline_Stack_Push(funcname);
    Inline_Stack_Push(args);
    Inline_Stack_Done;
}

/* return_string_error CODE MESSAGE EXTRA BUFFER OFFSET LENGTH
 * Construct an error return string for the error CODE and MESSAGE (and
 * optional EXTRA data). BUFFER, OFFSET and LENGTH as for serialise. */
unsigned char *return_string_error(const int code, SV *msg, SV *extra, unsigned char *buffer, size_t *off, size_t *len) {
    char cbuf[32], *s;
    STRLEN l;

    if (*off + 16 >= *len)
        buffer = realloc(buffer, *len += 16);
    buffer[(*off)++] = 'E';
    
    netstring_append(PROTOCOL_VERSION, (sizeof PROTOCOL_VERSION) - 1, buffer, off, len);
    
    /* Error code. */
    sprintf(cbuf, "%d", code);
    buffer = netstring_append(cbuf, strlen(cbuf), buffer, off, len);

    /* Error message. */
    s = SvPVbyte(msg, l);
    buffer = netstring_append(s, (size_t)l, buffer, off, len);
    
    /* Optional extra data. */
    if (SvOK(extra))
        buffer = serialise(extra, buffer, off, len);

    return buffer;
}

/* do_return_string_error CODE MESSAGE EXTRA
 * Return a serialised return-string for the given error CODE, MESSAGE and
 * optional EXTRA data. */
SV *do_return_string_error(int code, SV *msg, SV *extra) {
    SV *ret;
    char *buf;
    size_t off = 0, len;
    buf = malloc(len = 64);
    buf = return_string_error(code, msg, extra, buf, &off, &len);
    ret = newSVpvn(realloc(buf, off), off);
    return ret;
}

/* return_string_success X BUFFER OFFSET LENGTH
 * Construct a successful return string encoding X. BUFFER, OFFSET and LENGTH
 * as for serialise. */
unsigned char *return_string_success(SV *x, unsigned char *buffer, size_t *off, size_t *len) {
    char cbuf[32];
    STRLEN l;

    if (*off + 16 >= *len)
        buffer = realloc(buffer, *len += 16);
    buffer[(*off)++] = 'S';
    
    netstring_append(PROTOCOL_VERSION, (sizeof PROTOCOL_VERSION) - 1, buffer, off, len);
    
    return serialise(x, buffer, off, len);
}

/* do_return_string_success X
 * Return a serialised return-string for the return value X. */
SV *do_return_string_success(SV *x) {
    SV *ret;
    char *buf;
    size_t off = 0, len;
    buf = malloc(len = 64);
    buf = return_string_success(x, buf, &off, &len);
    ret = newSVpvn(realloc(buf, off), off);
    return ret;
}


EOF

