<?php
/*
 * PHP info admin page.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin-phpinfo.php,v 1.2 2004-11-11 12:38:03 francis Exp $
 * 
 */

class ADMIN_PAGE_PHPINFO {
    function ADMIN_PAGE_PHPINFO () {
        $this->id = "phpinfo";
        $this->name = "PHP Info";
        $this->navname = "PHP Environment Info";
    }

    function display($self_link) {
        ob_start();
        phpinfo();
        $php_info .= ob_get_contents();
        ob_end_clean();

        preg_match_all("=<body[^>]*>(.*)</body>=siU", $php_info, $a); 
        $php_info = $a[1][0]; 
        $php_info    = str_replace(" width=\"600\"", " width=\"600\"", $php_info);
        $php_info    = str_replace(";", "; ", $php_info);
        $php_info    = str_replace(",", ", ", $php_info);

        print $php_info;
    }
}

?>
