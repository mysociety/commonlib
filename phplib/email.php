<?php
/*
 * email.php:
 * Some shared functions for handling email. 
 * 
 * Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
 * Email: louise@mysociety.org; WWW: http://www.mysociety.org
 *
 * $Id: email.php,v 1.1 2009-05-06 09:43:57 louise Exp $
 * 
 */
 
/* verp_envelope_sender RECIPIENT PREFIX DOMAIN
 * Creates a string suitable for use as a VERP envelope sender for a mail to
 * RECIPIENT. PREFIX at DOMAIN needs to be set up to handle the bounces. */

function verp_envelope_sender($recipient, $prefix, $domain){
    
   list($recipient_mailbox, $recipient_domain) = split('@', $recipient);
   return $prefix . '+' . $recipient_mailbox . '=' . $recipient_domain . '@' . $domain;
}
 