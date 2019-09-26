<?php
/*
 * Embed other pages.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-embed.php,v 1.1 2005-02-23 13:42:36 francis Exp $
 * 
 */

class ADMIN_PAGE_EMBED {

    function __construct($id, $navname, $url) {
        $this->id = $id;
        $this->navname = $navname;
        $this->url = $url;
    }

    function ADMIN_PAGE_EMBED ($id, $navname, $url) {
      self::__construct($id, $navname, $url);
    }

    function display($self_link) {
        print $this->url;
    }
}

?>
