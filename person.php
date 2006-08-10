<?php
/*
 * person.php:
 * An individual user for the purpose of login etc.
 * 
 * Copyright (c) 2005 UK Citizens Online Democracy. All rights reserved.
 * Email: chris@mysociety.org; WWW: http://www.mysociety.org/
 *
 * $Id: person.php,v 1.20 2006-08-10 07:42:59 matthew Exp $
 * 
 */

require_once 'utility.php';
require_once 'stash.php';
require_once 'rabx.php';
require_once 'auth.php';

/* person_cookie_domain
 * Return the domain to use for cookies. This is computed from HTTP_HOST
 * so we can have multiple domains in one vhost. */
function person_cookie_domain() {
    $httphost = $_SERVER['HTTP_HOST'];
    if (preg_match("/[^.]+(\.com|\.owl|\.org||\.net|\.co\.uk|\.org\.uk)$/", $httphost, $matches)) {
        return "." . $matches[0];
    } else {
        return '.' . OPTION_WEB_DOMAIN;
    }
}

/* person_canonicalise_name NAME
 * Return NAME with all but alphabetic characters removed; this is used to
 * compare names entered by users to see when the record in the person table
 * should be updated. */
function person_canonicalise_name($n) {
    return preg_replace('/[^A-Za-z-]/', '', strtolower($n));
}

class Person {
    /* person ID | EMAIL
     * Given a person ID or EMAIL address, return a person object describing
     * their account. */
    function Person($id) {
        if (preg_match('/@/', $id))
            $this->id = db_getOne('select id from person where email = ? for update', $email);
        else if (preg_match('/^[1-9]\d*$/', $id))
            $this->id = db_getOne('select id from person where id = ? for update', $id);
        else
            err('value passed to person constructor must be person ID or email address');
        if (is_null($this->id))
            err("No such person '$id'");
        list($this->email, $this->name, $this->password, $this->website, $this->numlogins)
            = db_getRow_list('select email, name, password, website, numlogins from person where id = ?', $id);
    }

    /* id [ID]
     * Get the person ID. */
    function id() {
        return $this->id;
    }

    /* email [EMAIL]
     * Get or set the person's EMAIL address. */
    function email($email = null) {
        if (!is_null($email)) {
            db_query('update person set email = ? where id = ?', array($email, $this->id));
            $this->email = $email;
        }
        return $this->email;
    }

    /* name [NAME]
     * Get or set the person's NAME. */
    function name($name = null) {
        if (!is_null($name)) {
            db_query('update person set name = ? where id = ?', array($name, $this->id));
            db_commit();
            $this->name = $name;
        } elseif (is_null($this->name)) {
            err(_("Person has no name in name() function")); // try calling name_or_blank or has_name 
        }
        return $this->name;
    }
    
    /* name_or_blank
     * Get the person's name, or empty string if unknown.  Use this as
     * prefilled name field in forms. */
    function name_or_blank() {
        if ($this->name) 
            return $this->name;
        else
            return "";
    }

    /* has_name
     * Returns true if we have a name for the person */
    function has_name() {
        return $this->name ? true : false;
    }

    /* set_website WEBSIte
     * Set name of person's website. */
    function set_website($website) {
        db_query('update person set website = ? where id = ?', array($website, $this->id));
        $this->website = $website;
    }

    /* website_or_blank
     * Get the person's website, or empty string if unknown.  Use this
     * as prefilled website field in comment forms. */
    function website_or_blank() {
        if ($this->website) 
            return $this->website;
        else 
            return "";
    }

    /* matches_name [NEWNAME]
     * Is NEWNAME essentially the same as the person's existing name? */
    function matches_name($newname) {
        if (!$this->name)
            return false;
        if (!$newname) 
            err(_("Name expected in matches_name"));
        return person_canonicalise_name($newname) == person_canonicalise_name($this->name);
    }

    /* password PASSWORD
     * Set the person's PASSWORD. */
    function password($password) {
        if (is_null($password))
            err(_("PASSWORD must not be null in password method"));
        db_query('update person set password = ? where id = ?', array(crypt($password), $this->id));
    }

    /* has_password
     * Return true if the user has set a password. */
    function has_password() {
        return !is_null($this->password);
    }

    /* check_password PASSWORD
     * Return true if PASSWORD is the person's password, or false otherwise. */
    function check_password($p) {
        $c = db_getOne('select password from person where id = ?', $this->id);
        if (is_null($c))
            return false;
        else if (crypt($p, $c) != $c)
            return false;
        else
            return true;
    }

    /* numlogins
     * How many times has this person logged in? */
    function numlogins() {
        return $this->numlogins;
    }

    /* inc_numlogins
     * Record this person as having logged in an additional time. */
    function inc_numlogins() {
        ++$this->numlogins;
        db_query('update person set numlogins = numlogins + 1 where id = ?', $this->id);
    }
}

/* person_cookie_token ID [DURATION]
 * Return an opaque version of ID to identify a person in a cookie. If
 * supplied, DURATION is how long the cookie will last (verified by the
 * server); if not specified, a default of one year is used. */
function person_cookie_token($id, $duration = null) {
    if (is_null($duration))
        $duration = 365 * 86400; /* one year */
    if (!preg_match('/^[1-9]\d*$/', $id))
        err("ID should be a decimal integer, not '$id'");
    if (!preg_match('/^[1-9]\d*$/', $duration) || $duration <= 0)
        err("DURATION should be a positive decimal integer, not '$duration'");
    $salt = bin2hex(random_bytes(8));
    $start = time();
    $sha = sha1("$id/$start/$duration/$salt/" . db_secret());
    return sprintf('%d/%d/%d/%s/%s', $id, $start, $duration, $salt, $sha);
}

/* person_check_cookie_token TOKEN
 * Given TOKEN, allegedly representing a person, test it and return the
 * associated person ID if it is valid, or null otherwise. On successful
 * return from this function the database row identifying the person will
 * have been locked with SELECT ... FOR UPDATE. */
function person_check_cookie_token($token) {
    $a = array();
    if (!preg_match('#^([1-9]\d*)/([1-9]\d*)/([1-9]\d*)/([0-9a-f]+)/([0-9a-f]+)$#', $token, $a))
        return null;
    list($x, $id, $start, $duration, $salt, $sha) = $a;
    if (sha1("$id/$start/$duration/$salt/" . db_secret()) != $sha)
        return null;
    elseif ($start + $duration < time())
        return null;
    elseif (is_null(db_getOne('select id from person where id = ? for update', $id)))
        return null;
    else
        return $id;
}

/* person_cookie_token_duration TOKEN
 * Given a valid cookie TOKEN, return the duration for which it was issued. */
function person_cookie_token_duration($token) {
    list($x, $start, $duration) = explode('/', $token);
    return $duration;
}

/* Global variable storing the identity of any signed-on person. Since
 * person_if_signed_on renews the user's cookie and multiple calls to
 * setcookie() with the same cookie name just add further Set-Cookie: headers,
 * we need to make sure the cookie is only sent once. Really the proper way to
 * do this is to have a flag which means "cookie sent", but that turned out to
 * be a historical impossibility.... */
$person_signed_on = null;

/* person_if_signed_on [NORENEW]
 * If the user has a valid login cookie, return the corresponding person
 * object; otherwise, return null. This function will renew any login cookie,
 * unless NORENEW is set. */
function person_if_signed_on($norenew = false) {
    global $person_signed_on;
    if (!is_null($person_signed_on))
        return $person_signed_on;
    if (array_key_exists('pb_person_id', $_COOKIE)) {
        /* User has a cookie and may be logged in. */
        $id = person_check_cookie_token($_COOKIE['pb_person_id']);
        if (!is_null($id)) {
            $P = new Person($id);
            if (!$norenew) {
                /* Valid, so renew the cookie. */
		# XXX: This turns all session cookies into one-year ones!
                $duration = person_cookie_token_duration($_COOKIE['pb_person_id']);
                setcookie('pb_person_id', person_cookie_token($id, $duration), time() + $duration, '/', person_cookie_domain());
                $person_signed_on = $P; /* save this here so we will renew the cookie on a later call to this function without NORENEW */
            }
            return $P;
        }
    }
    return null;   
}

function person_already_signed_on($email, $name, $person_if_signed_on_function) {
    if (!is_null($email) && !validate_email($email))
        err("'$email' is not a valid email address");

    if ($person_if_signed_on_function)
        $P = $person_if_signed_on_function();
    else
        $P = person_if_signed_on();
    if (!is_null($P) && (is_null($email) || $P->email() == $email)) {
        if (!is_null($name) && !$P->matches_name($name))
            $P->name($name);
        return $P;
    }

    return null;
}

/* person_signon DATA [EMAIL] [NAME]
 * Return a record of a person, if necessary requiring them to sign on to an
 * existing account or to create a new one. 
 * 
 * DATA is an array of data about the pledge, including 
 *  'reason_web' which is something like 'Before you can send a message to
 *      all the signers, we need to check that you created the pledge.' and
 *      appears above the send confirm email / login by password dialog.
 *  'template' which is the name of the template to use for the confirm
 *      mail if the user authenticates by email rather than password.
 *  'reason_email' is used if and only if 'template' isn't present, and
 *      goes into the generic-confirm template.  It says something like 'Then
 *      you will be able to send a message to everyone who has signed your
 *      pledge.'
 *  'reason_email_subject' gives Subject: line of email, must be present
 *      when 'reason_email' is present.
 *  'instantly_send_email' if present means the user is prompted as to whether
 *      to log in by password or by email authentication, they are just sent the
 *      email immediately
 * The rest of the DATA is passed through to the email template. 
 * 
 * EMAIL, if present, is the email address to log in with.  Otherwise, an email
 * addresses is prompted for.  
 *
 * NAME is also optional, and if present updates/creates the default name
 * record for the email address.  If you do not specify a name here, then
 * calling the $this->name() function later will give an error.  Instead call
 * $this->name_or_blank() or $this->has_name().  The intention here is that if
 * the action requires a name, you will have prompted for it in an earlier form
 * and included it in the call to this function. 
 * 
 * PERSON_IF_SIGNED_ON_FUNCTION, if present, is a function pointer to a wrapper
 * for the function person_if_signed_on(). person_signon() will call that wrapper
 * instead of person_if_signed_on() directly. This is totally ugly, but will do.
 * */
function person_signon($template_data, $email = null, $name = null, $person_if_signed_on_function = null) {
    $P = person_already_signed_on($email, $name, $person_if_signed_on_function);
    if ($P)
        return $P;

    /* Get rid of any previous cookie -- if user is logging in again under a
     * different email, we don't want to remember the old one. */
    person_signoff();

    if (headers_sent())
        err("Headers have already been sent in person_signon without cookie being present");

    if (array_key_exists('instantly_send_email', $template_data)) {
        $send_email_part = "&SendEmail=1";
        unset($template_data['instantly_send_email']);
    } else
        $send_email_part = '';
    /* No or invalid cookie. We will need to redirect the user via another
     * page, either to log in or to prove their email address. */
    $st = stash_request(rabx_serialise($template_data));
    db_commit();
    if ($email)
        $email_part = "&email=" . urlencode($email);
    else
        $email_part = "";
    if ($name) 
        $name_part = "&name=" . urlencode($name);
    else
        $name_part = "";
    header("Location: /login?stash=$st$send_email_part$email_part$name_part");
    exit();
}

/* person_signoff
 * Log out anyone who is logged in */
function person_signoff() {
    setcookie('pb_person_id', '', 0, '/', person_cookie_domain());
    # Remove old style cookies left around too
    setcookie('pb_person_id', '', 0, '/', '.' . OPTION_WEB_DOMAIN);
}

/* person_make_signon_url DATA EMAIL METHOD URL PARAMETERS
 * Returns a URL which, if clicked on, will log the user in as EMAIL and have
 * them do the request described by METHOD, URL and PARAMETERS (as used in
 * stash_new_request). DATA is as for person_signon (but the 'template' and
 * 'reason_' entires won't be used since presumably the caller is constructing
 * its own email to send). */
function person_make_signon_url($data, $email, $method, $url, $params, $url_base = null) {
    if (!$url_base)
        $url_base = OPTION_BASE_URL . "/";

    $st = stash_new_request($method, $url, $params, $data);
    /* XXX should combine this and the similar code in login.php. */
    $token = auth_token_store('login', array(
                    'email' => $email,
                    'name' => null,
                    'stash' => $st,
                    'direct' => 1
                ));
    return $url_base . "L/$token";
}

/* person_get EMAIL
 * Return a person object for the account with the given EMAIL address, if one
 * exists, or null otherwise. */
function person_get($email) {
    $id = db_getOne('select id from person where email = ? for update', $email);
    if (is_null($id))
        return null;
    else
        return new Person($id);
}

/* person_get_or_create EMAIL [NAME]
 * If there is an existing account for the given EMAIL address, return the
 * person object describing it. Otherwise, create a new account for EMAIL and
 * NAME, and return the object describing it. */
function person_get_or_create($email, $name = null) {
    if (is_null($email))
        err('EMAIL null in person_get_or_create');
        /* XXX case-insensitivity of email addresses? */
    $id = db_getOne('select id from person where email = ?', $email);
    if (is_null($id)) {
        db_query('lock table person in share mode');    /* Guard against double-insert. */
        $id = db_getOne("select nextval('person_id_seq')");
        db_query('insert into person (id, email, name) values (?, ?, ?)', array($id, $email, $name));
    }
    return new Person($id);
}

?>
