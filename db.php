<?
// db.php:
// Interface to (PostgreSQL) database 
//
// This is a wrapper round PEAR's DB. Unfortunately, DB doesn't behave
// in the same way as Perl's DBI. It 
// - doesn't start a transaction automatically, unless you make a query
//   it believes to be a modifying one
// - doesn't commit at all unless you have done a query which it 
//   believes to be a modifying one
// Its test of "modifying query" is based on simple string search, so
// it fails when you call a function with side effects via SELECT.
//
// So, we do our own query calls through to begin, commit and rollback.
// This also means we have to maintain transaction_opcount ourselves,
// so DB/pgsql.php doesn't do its own unnecessary extra "begin" calls.
//
// Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org. WWW: http://www.mysociety.org
//
// $Id: db.php,v 1.13 2006-03-15 10:33:22 chris Exp $

require_once "DB.php";
require_once "utility.php";

/* db_connect
 * Connect a global handle to the database. */
function db_connect() {
    global $pbdb;
    $vars = array('hostspec'=>'HOST', 'port'=>'PORT', 'database'=>'NAME', 'username'=>'USER', 'password'=>'PASS');
    $connstr = array('phptype'=>'pgsql');
    if (defined('OPTION_DB_TYPE')) {
        $connstr['phptype'] = OPTION_DB_TYPE;
    }
    $prefix = OPTION_PHP_MAINDB;
    foreach ($vars as $k => $v) {
        if (defined('OPTION_' . $prefix . '_DB_' . $v)) {
            $connstr[$k] = constant('OPTION_' . $prefix . '_DB_' . $v);
        }
    }
    $connstr['connect_timeout'] = 10;
    /*  set 'persistent' => true to get persistent DB connections. 
     *  TODO: ensure
     *  - the connection hasn't died (I think it handles this)
     *  - that we can't have more PHP processes than the database server
     *  permits connections. */
    $persistent = false;
    if (defined('OPTION_' . $prefix . '_DB_' . 'PERSISTENT')) {
        $persistent = constant('OPTION_' . $prefix . '_DB_' . 'PERSISTENT') ? true : false;
    }
    $options = array( 'persistent' => $persistent );
    $pbdb = DB::connect($connstr, $options);
    if (DB::isError($pbdb)) {
        die($pbdb->getMessage());
    }

    $pbdb->autoCommit(false);

    /* Since we are using persistent connections we might end up re-using a
     * connection which is in the middle of a transaction. So try to roll back
     * any open transaction on termination of the script. */
    register_shutdown_function('db_rollback');

    /* Ensure that we have a site shared secret. */
    $pbdb->query('begin');
    $r = $pbdb->getOne('select secret from secret');
    if (is_null($r)) {
        $pbdb->transaction_opcount++;
        if (DB_OK == $pbdb->query('insert into secret (secret) values (?)', array(bin2hex(random_bytes(32)))))
            $pbdb->query('commit');
        else
            $pbdb->query('rollback');
        $pbdb->transaction_opcount++;
        $pbdb->query('begin');
    }
}

/* db_secret
 * Return the site shared secret. */
function db_secret() {
    return db_getOne('select secret from secret');
}

/* db_query QUERY PARAMETERS
 * Perform QUERY against the database. Values in the PARAMETERS array are
 * substituted for '?' in the QUERY. Returns a query object or dies on
 * failure. */
function db_query($query, $params = array()) {
    global $pbdb;
    if (!is_array($params))
        $params = array($params);
    if (!isset($pbdb))
        db_connect();
    $result = $pbdb->query($query, $params);
    if (DB::isError($result)) {
        die($result->getMessage().': "'.$result->getDebugInfo().'"; query was: ' . $query);
    }
    return $result;
}

/* db_getOne QUERY PARAMETERS
 * Execute QUERY and return a single value of a single column. */
function db_getOne($query, $params = array()) {
    global $pbdb;
    if (!is_array($params))
        $params = array($params);
    if (!isset($pbdb))
        db_connect();
    $result = $pbdb->getOne($query, $params);
    if (DB::isError($result)) {
        die($result->getMessage().': "'.$result->getDebugInfo().'"; query was: ' . $query);
    }
    return $result;
}

/* db_getRow QUERY PARAMETERS
 * Execute QUERY and return an associative array of the columns of the first
 * row returned. */
function db_getRow($query, $params = array()) {
    global $pbdb;
    if (!is_array($params))
        $params = array($params);
    if (!isset($pbdb))
        db_connect();
    $result = $pbdb->getRow($query, $params, DB_FETCHMODE_ASSOC);
    if (DB::isError($result)) {
        die($result->getMessage().': "'.$result->getDebugInfo().'"; query was: ' . $query);
    }
    return $result;
}

/* db_getRow_list QUERY PARAMETERS
 * Like db_getRow, but return an array not an associative array. */
function db_getRow_list($query, $params = array()) {
    global $pbdb;
    if (!is_array($params))
        $params = array($params);
    if (!isset($pbdb))
        db_connect();
    $result = $pbdb->getRow($query, $params, DB_FETCHMODE_ORDERED);
    if (DB::isError($result))
        die($result->getMessage().': "'.$result->getDebugInfo().'"; query was: ' . $query);
    return $result;
}

function db_getAll($query, $params = array()) {
    global $pbdb;
    if (!is_array($params))
        $params = array($params);
    if (!isset($pbdb))
        db_connect();
    $result = $pbdb->getAll($query, $params, DB_FETCHMODE_ASSOC);
    if (DB::isError($result))
        die($result->getMessage().': "'.$result->getDebugInfo().'"; query was: ' . $query);
    return $result;
}

/* db_fetch_array QUERY
 * Fetch values of the next row from QUERY as an associative array from column
 * name to value. */
function db_fetch_array($q) {
    return $q->fetchRow(DB_FETCHMODE_ASSOC);
}

/* db_fetch_row QUERY
 * Fetch values of the next row from QUERY as an array. */
function db_fetch_row($q) {
    return $q->fetchRow(DB_FETCHMODE_ORDERED);
}

/* db_num_rows QUERY
 * Return the number of rows returned by QUERY. */
function db_num_rows($q) {
    return $q->numRows();
}

/* db_affected_rows QUERY
 * Return the number of rows affected by the most recent query. */
function db_affected_rows() {
    global $pbdb;
    if (!isset($pbdb))
        die("db_affected_rows called before any query made");
    return $pbdb->affectedRows();
}

/* db_commit
 * Commit current transaction. */
function db_commit () {
    global $pbdb;
    // PEAR DB ->commit() doesn't commit if it believes no updates/inserts
    // were done. So any select with side effects wouldn't commit.
    $pbdb->query('commit');
    $pbdb->transaction_opcount = 1;
    $pbdb->query('begin');
}

/* db_rollback
 * Roll back current transaction. */
function db_rollback () {
    global $pbdb;
    $pbdb->query('rollback');
    $pbdb->transaction_opcount = 1;
    $pbdb->query('begin');
}

?>
