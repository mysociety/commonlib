<?
// db.php:
// Interface to database for PledgeBank
// TODO:  Perhaps get rid of this file, as PEAR's DB is good enough alone.
//
// Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
// Email: francis@mysociety.org. WWW: http://www.mysociety.org
//
// $Id: db.php,v 1.3 2005-10-07 19:07:58 matthew Exp $

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
    $pbdb = DB::connect($connstr);
    if (DB::isError($pbdb)) {
        die($pbdb->getMessage());
    }
    
    /* Ensure that we have a site shared secret. */
    $pbdb->query('lock table secret in share mode');
    $r = $pbdb->getOne('select secret from secret');
    if (is_null($r))
        $pbdb->query('insert into secret (secret) values (?)', array(bin2hex(random_bytes(32))));
    $pbdb->commit();
    
    $pbdb->autoCommit(false);
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
    $pbdb->commit();
}

/* db_rollback
 * Roll back current transaction. */
function db_rollback () {
    global $pbdb;
    $pbdb->rollback();
}

?>
