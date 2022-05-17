<?php
// db.php:
// Interface to (PostgreSQL) database 
//
// This is a wrapper around PHP's native pg_* calls. Originally it wrapped the
// PEAR DB calls, but this has been abandoned on performance grounds (because
// the PEAR library is so large that parsing it on each page view gave a
// significant performance hit). We do retain the ability to perform queries
// with '?' as placeholder for bind variables, and emulate the previous
// behaviour of always running statements in a transaction.
//
// Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org. WWW: http://www.mysociety.org
//
// $Id: db.php,v 1.32 2006-11-13 22:52:42 francis Exp $

require_once dirname(__FILE__) . '/error.php';
require_once dirname(__FILE__) . '/random.php';

$db_log_queries = false; # set to true to log all queries to Apache error log
function _db_pg_query($db_h, $q) {
    global $db_log_queries;
    if ($db_log_queries)
        error_log($q);
    return pg_query($db_h, $q);
}

/* db_subst QUERY [PARAM ...]
 * Given an SQL QUERY containing zero or more "?"s, substitute quoted values of
 * the PARAMs into the query and return the new text. If the only non-QUERY
 * parameter is a single array, then values are taken from that array rather
 * than from the function's parameters. */
function db_subst($q) {
    if (func_num_args() == 1)
        return $q;
    else if (func_num_args() == 2) {
        $params = func_get_arg(1);
        if (!is_array($params))
            $params = array($params);
    } else {
        $params = func_get_args();
        array_shift($params);
    }
    $ss = preg_split('/(\?)/', $q, -1, PREG_SPLIT_DELIM_CAPTURE);
    $result = '';
    foreach ($ss as $s) {
        if ($s == '?') {
            if (count($params) == 0)
                err("not enough substitution parameters for query '$q'");
            $v = array_shift($params);
            if (is_null($v))
                $result .= 'null';
            else if (is_bool($v))
                $result .= $v ? 'true' : 'false';
            else if (is_int($v) || is_float($v))
                $result .= $v;
            else
                $result .= "'" . pg_escape_string($v) . "'";
        } else
            $result .= $s;
    }

    if (count($params) > 0)
        err("too many substitution parameters for query '$q'");

    return $result;
}

/* db_connect
 * Connect a global handle to the database. */
function db_connect() {
    global $db_h;
    $vars = array('host' => 'HOST', 'port' => 'PORT', 'dbname' => 'NAME', 'user' => 'USER', 'password' => 'PASS');
/*    if (defined('OPTION_DB_TYPE'))
        $connstr['phptype'] = OPTION_DB_TYPE; */ /* what is this for? */
    $prefix = OPTION_PHP_MAINDB;

    $connstr = '';
    foreach ($vars as $k => $v) {
        if (defined("OPTION_${prefix}_DB_$v"))
            $connstr .= " $k='" .  constant("OPTION_${prefix}_DB_$v") . "'";
    }
    $connstr .= " connect_timeout=10 sslmode=prefer";

    /*  set 'persistent' => true to get persistent DB connections. 
     *  TODO: ensure
     *  - the connection hasn't died (I think it handles this)
     *  - that we can't have more PHP processes than the database server
     *  permits connections. */
    $persistent = false;
    if (defined("OPTION_${prefix}_DB_PERSISTENT"))
        $persistent = constant("OPTION_${prefix}_DB_PERSISTENT") ? true : false;

    if ($persistent)
        $db_h = pg_pconnect($connstr);
    else
        $db_h = pg_connect($connstr);

    if (!$db_h)
        err("unable to connect to database: " . pg_lasterror());

    /* Since we are using persistent connections we might end up re-using a
     * connection which is in the middle of a transaction. So try to roll back
     * any open transaction on termination of the script. */
    register_shutdown_function('db_end');

    _db_pg_query($db_h, 'begin');

    /* Ensure that we have a site shared secret. */
    global $db_secret_value;
    $r = _db_pg_query($db_h, 'select secret from secret');
    $secret_row = pg_fetch_row($r);
    if (!$secret_row) {
        $db_secret_value = bin2hex(random_bytes(32));
        if (_db_pg_query($db_h, db_subst('insert into secret (secret) values (?)', $db_secret_value)))
            _db_pg_query($db_h, 'commit');
        else
            _db_pg_query($db_h, 'rollback');
        _db_pg_query($db_h, 'begin');
    } else {
        $db_secret_value = $secret_row[0];
    }
}

/* db_secret
 * Return the site shared secret. */
function db_secret() {
    global $db_secret_value;
    if (!$db_secret_value)
        $db_secret_value = db_getOne('select secret from secret');
    return $db_secret_value;
}

/* db_query_literal QUERY
 * Perform QUERY with no parameter substitution. */
function db_query_literal($query) {
    global $db_h;
    global $db_last_res;
    if (!isset($db_h))
        db_connect();
    if (!($db_last_res = _db_pg_query($db_h, $query)))
        err(pg_last_error($db_h) . "in literal query '$query'");
    return $db_last_res;
}

/* db_query QUERY [PARAM ...]
 * Perform QUERY against the database. Values of the PARAMs are substituted
 * for '?' in the QUERY; if the single PARAM is an array, values from that are
 * used instead. Returns a query object or dies on failure. */
function db_query($query) {
    global $db_h;
    global $db_last_res;
    if (!isset($db_h))
        db_connect();
    /* ugly boilerplate to call through to db_subst */
    $a = func_get_args();
    $q = call_user_func_array('db_subst', $a);
    global $db_log_queries;
    if (!($db_last_res = _db_pg_query($db_h, $q))) {
        // TODO: Unfortunately, this never gets called, as a PostgreSQL error
        // causes pg_query to raise a PHP warning, which our error checking
        // code correctly counts as an error, during execution of the if
        // statement above.  Not sure how best to fix this, as would be nice to
        // print the query, like this line attempts to:
        err(pg_last_error($db_h) . " in query '$query'");
    }
    return $db_last_res;
}

/* db_do QUERY [PARAM ...]
 * Perform QUERY (presumably an INSERT, UPDATE or DELETE) against the database.
 * Values of the PARAMS are substituted as for db_query. Dies on failure or
 * returns the number of rows affected on success. */
function db_do($query) {
    $a = func_get_args();
    $r = call_user_func_array('db_query', $a);
    return pg_affected_rows($r);
}

/* db_getOne QUERY [PARAM ...]
 * Execute QUERY and return a single value of a single column. */
function db_getOne($query) {
    $a = func_get_args();
    $r = call_user_func_array('db_query', $a);
    if (!($row = pg_fetch_row($r)))
        return null;
    else
        return $row[0];
}

/* db_getRow QUERY [PARAM ...]
 * Execute QUERY and return an associative array of the columns of the first
 * row returned. */
function db_getRow($query) {
    $a = func_get_args();
    $r = call_user_func_array('db_query', $a);
    return db_fetch_array($r);
}

/* db_getRow_list QUERY [PARAM ...]
 * Like db_getRow, but return an array not an associative array. */
function db_getRow_list($query) {
/* XXX could probably use db_getRow anyway, as the associative array will also
 * have the columns in order anyway. */
    $a = func_get_args();
    $r = call_user_func_array('db_query', $a);
    return db_fetch_row($r);
}

/* db_getAll QUERY [PARAM ...]
 * Do QUERY and return all results as an array of associative arrays of rows.
 * This returns the empty array if there are no results, or if an error
 * occurs, so it cannot be used if you need to be able to detect an error. */
function db_getAll($query) {
    $a = func_get_args();
    $r = call_user_func_array('db_query', $a);
    $res = pg_fetch_all($r);
    if ($res == false) $res = array();
    return $res;
}

/* db_fetch_array RESULTS
 * Fetch values of the next row from RESULTS as an associative array from column
 * name to value. */
function db_fetch_array($r) {
    $res = pg_fetch_array($r);
    if (!$res) $res = null;
    return $res;
}

/* db_fetch_row QUERY
 * Fetch values of the next row from RESULTS as an array. */
function db_fetch_row($r) {
    $res = pg_fetch_row($r);
    if (!$res) $res = null;
    return $res;
}

/* db_num_rows RESULTS
 * Return the number of rows returned in RESULTS. */
function db_num_rows($r) {
    return pg_num_rows($r);
}

/* db_affected_rows QUERY
 * Return the number of rows affected by the most recent query. */
function db_affected_rows() {
    global $db_last_res;
    global $db_h;
    if (!isset($db_h))
        err("db_affected_rows called before any query made");
    return pg_affected_rows($db_last_res);
}

/* db_commit
 * Commit current transaction. */
function db_commit () {
    global $db_h;
    _db_pg_query($db_h, 'commit');
    _db_pg_query($db_h, 'begin');
}

/* db_rollback
 * Roll back current transaction. */
function db_rollback () {
    global $db_h;
    _db_pg_query($db_h, 'rollback');
    _db_pg_query($db_h, 'begin');
}

/* db_end
 * Cleanup at end of session. */
function db_end() {
    global $db_h;
    if (isset($db_h)) {
        _db_pg_query($db_h, 'rollback');
        $db_h = null;
    }
}

/* db_get_locks
 * Returns description of locks on the database. For debugging. 
 * XXX this doesn't seem to work, some permissions issue? */
function db_get_locks() {
    $prefix = OPTION_PHP_MAINDB;
    $dbname = "OPTION_${prefix}_DB_dbname";
    $ret = "datname,relname,transaction,mode,granted,usename,substr,query_start,age,procpid\n";

    $q = db_query('select pg_stat_activity.datname,pg_class.relname,pg_locks.transaction, pg_locks.mode, pg_locks.granted,pg_stat_activity.usename,substr(pg_stat_activity.current_query,1,30), pg_stat_activity.query_start, age(now(),pg_stat_activity.query_start) as "age", pg_stat_activity.procpid 
    from pg_stat_activity,pg_locks 
    left outer join pg_class on (pg_locks.relation = pg_class.oid)  
    where pg_locks.pid=pg_stat_activity.procpid 
    order by query_start'
#and pg_stat_activity.datname = ? 
#    , $dbname
    );
    while ($row = db_fetch_row($q)) {
        $ret .= join(",", $row) . "\n";
    }
    return $ret;
}

?>
