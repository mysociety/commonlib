#!/usr/bin/perl -w
#
# RABX/Fast.pm:
# Fast (C) serialisation code.
#
# Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
# Email: chris@mysociety.org; WWW: http://www.mysociety.org/
#

package RABX::Fast;

my $rcsid = ''; $rcsid .= '$Id: Fast.pm,v 1.2 2005-02-17 00:28:25 chris Exp $';

use strict;

use Inline C => Config => CCFLAGS => '-g';

use Inline C => <<'EOF';

#include <perl.h>

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
 * on success, and updates *OFFSET (and perhaps *LENGTH). */
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
                n = snprintf(b, sizeof b, "%d", (int)(N = hv_iterinit((HV*)y)))
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

SV *do_serialise(SV *x) {
    SV *ret;
    char *buf;
    size_t off = 0, len;
    buf = malloc(len = 64);
    buf = serialise(x, buf, &off, &len);
    ret = newSVpvn(buf, off);
    free(buf);
    return ret;
}
EOF

