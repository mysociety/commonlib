<?php
/*
 * auth.php:
 * Authentication for pledgebank.  Token related code.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: auth.php,v 1.1 2005-07-08 11:33:02 matthew Exp $
 * 
 */

/* auth_ab64_encode DATA
 * Return a "almost base64" encoding of DATA (a nearly six-bit encoding using
 * email-client-friendly characters; specifically the encoded data match
 * /^[0-9A-Za-z]+$/). 
 * TODO: Change this to proper base62_encode :) */
function auth_ab64_encode($i) {
    $t = base64_encode($i);
    $t = str_replace("+", "a", &$t);
    $t = str_replace("/", "b", &$t);
    $t = str_replace("=", "c", &$t);
    return $t;
}

/* auth_random_token
 * Returns a random token. */
function auth_random_token() {
    $token = auth_ab64_encode(random_bytes(12));
    return $token;
}

/* auth_token_store SCOPE DATA
 * Returns a randomly generated token, suitable for use in URLs. SCOPE is the
 * associated scope. DATA (of arbitrary, non-object type) are serialised and
 * stored in the database associated with that scope and token, for later
 * retrieval with auth_random_token_retrieve. */
function auth_token_store($scope, $data) {
    $token = auth_random_token();
    $ser = '';
    rabx_wire_wr($data, $ser);
    db_query('
            insert into token (scope, token, data, created)
            values (?, ?, ?, pb_current_timestamp())', array($scope, $token, $ser));
    return $token;
}

/* auth_token_retrieve SCOPE TOKEN
 * Given a TOKEN returned by auth_random_token_store for the given SCOPE,
 * return the DATA associated with it, raising an error if there isn't one. */
function auth_token_retrieve($scope, $token) {
    $data = db_getOne('
                    select data
                    from token
                    where scope = ? and token = ?', array($scope, $token));

    /* Madness. We have to unescape this, because the PEAR DB library isn't
     * smart enough to spot BYTEA columns and do it for us. */
    $data = pg_unescape_bytea($data);

    $pos = 0;
    $res = rabx_wire_rd(&$data, &$pos);
    if (rabx_is_error($res)) {
        $res = unserialize($data);
        if (is_null($res))
            err("Data for scope '$scope', token '$token' are not valid");
    }

    return $res;
}

/* auth_token_destroy SCOPE TOKEN
 * Delete any data associated with TOKEN in the given SCOPE. */
function auth_token_destroy($scope, $token) {
    db_query('delete from token where scope = ? and token = ?',
            array($scope, $token));
}


