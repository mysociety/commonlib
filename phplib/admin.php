<?php
/*
 * Infrastructure for administration pages.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin.php,v 1.42 2010-03-12 19:13:30 matthew Exp $
 * 
 */

require_once dirname(__FILE__) . "/utility.php";

// Error display
require_once dirname(__FILE__) . "/error.php";
function admin_display_error($num, $message, $file, $line, $context) {
    print "<p><strong>$message</strong> in $file:$line</p>";
}
err_set_handler_display('admin_display_error');

/*

admin_page_display is used to create an admin section of a website. SITE_NAME
is used for a display title, PAGES is an array of admin pages (described
below), and default (optional) is an admin page to show on the main page.

PAGES can also contain null items for breaks in the list of pages.

An admin page is an object that has, at minimum, an id string and a display
function.  The id string is used in the URL of the admin page, and the display
function is called to display that page. The web-admin directories for each
project contain examples of this function in the index.php files.

*/

function admin_page_display($site_name, $pages, $default = null, $params = array()) {
    $maintitle = "$site_name admin";
    if (get_http_var("page"))  {
        // find page
        $id = get_http_var("page");
        foreach ($pages as $page) {
            if (isset($page) && $page->id == $id) {
                break;
            }
        } 
        // display
        ob_start();
        if (isset($page->contenttype)) {
            header($page->contenttype);
        } else {
            header("Content-Type: text/html; charset=utf-8");
            if (!isset($params['headfoot'])) {
                $title = $page->navname . " - $maintitle";
                admin_html_header($title);
                if (isset($params['shownavbar']) && $params['shownavbar']){
                    print admin_navigation_bar($pages, $page->id, $params['shownavbar']);
                }
                print "<h1>$title</h1>";
            }
        }
        $self_link = "?page=$id";
        $page->self_link = $self_link;
        $page->display($self_link); # TODO remove this as parameter, use class member
        if (!isset($page->contenttype)) {
            admin_html_footer();
        }
    } else {
        header("Content-Type: text/html; charset=utf-8");
        if (!isset($params['headfoot'])) {
            admin_html_header($maintitle);
            print '<h3>' . $site_name . '</h3>';
        }
        if (!is_null($default)) {
            $default->display();
        }

        print admin_navigation_bar($pages);
?>
<p><a href="http://www.mysociety.org/"><img class="mslogo" src="https://secure.mysociety.org/mysociety_sm.gif" border="0" alt="mySociety"></a></p>
<?php
        admin_html_footer();
    } 
}

// generate navigation bar
function admin_navigation_bar($pages, $currentPageId = null, $wantStyling = false) {
    $need_separator = false; # start a new <ul> when one or more nulls are found
    // ignoring actual value of wantStyling, but one day perhaps it could be a CSS class name?
    $navlinks = $wantStyling? "<div class='admin-page-nav'>" : "<div>";
    $navlinks .= "<ul>";
    foreach ($pages as $page) {
        if (isset($page)) {
            if ($need_separator) {
                $navlinks .= '</ul> <ul>';
                $need_separator = false;
            }
            if ($currentPageId && isset($page->id) && $currentPageId == $page->id) {
                $navlinks .= "<li><span class='admin-no-link'>" . $page->navname. "</span></li>";
            } elseif (isset($page->url)) {
                $navlinks .= "<li><a href=\"". $page->url."\">" . $page->navname. "</a></li>";
            } elseif (!property_exists($page, 'noindex') || !$page->noindex) {
                $navlinks .= "<li><a href=\"?page=". $page->id."\">" . $page->navname. "</a></li>";
            }
        } else {
            $need_separator = true;
        }
    }
    $navlinks .= '</ul>';
    if ($wantStyling) {
        $navlinks .= '<div class="admin-nav-clear"></div>';
    }
    $navlinks .= '</div>';
    return $navlinks;
}

// Header at start of page
function admin_html_header($title) {
?>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<style type="text/css"><!--
body {background-color: #ffffff;  color: #000000; }
body,  td,  th,  h1,  h2 {font-family: sans-serif; }
pre {margin: 0px;  font-family: monospace; }
a:link {text-decoration: none; }
a:visited {text-decoration: none; }
a:active {text-decoration: underline; }
a:hover {text-decoration: underline; }
table {border-collapse: collapse; }
.center {text-align: center; }
.center table { margin-left: auto;  margin-right: auto;  text-align: left; }
.center th { text-align: center !important;  }
td,  th { font-size: 75%; }
h1 {font-size: 150%; }
h2 {font-size: 125%; }
.p {text-align: left; }
.e {background-color: #ccccff;  font-weight: bold;  color: #000000; }
.h {background-color: #9999cc;  color: #000000; }
.v {background-color: #cccccc;  color: #000000; }
.l {background-color: #ffcccc;  color: #000000; }
.v.l {background-color: #ff9999;  color: #000000; }
.difffrom {background-color: #99ff66; }
.diffto {background-color: #99ffcc; }
.diffsnip {background-color: #ccff33; }
i,em {color: #666666;  background-color: #cccccc; }
img.mslogo {float: left;  border: 0px; }
hr {width: 600px;  background-color: #cccccc;  border: 0px;  height: 1px;  color: #000000; }
img.creatorpicture { float: left; display: inline; margin-right: 10px; }
.timeline dt {   clear: left; float: left; font-weight: bold; }
.timeline dd { margin-left: 8em; }
#pledge { border: solid 2px #522994; background-color: #f6e5ff; margin-bottom: 1em; margin-left: 1em; padding: 10px; text-align: center; width: 30%; float: right; margin: 1em auto; }
/* admin- classes introduced for pledgebank */
.admin-even, .admin-odd { padding:6px 4px; background-color: #ffffff; margin:0; clear:left;}
.admin-odd { background-color: #eeeeee; }
.admin-name { width:8em; float:left; color:#666666; }
.admin-value  { 
    margin-left:8em; 
    min-height: 1em;
    height: auto !important; /* this line and the next: hack for ie6*/ 
    height: 1em;
}
.admin-value h2  { margin-top:0; font-size:1em; }
/* slightly fancy admin nav introduced for pledgebank pages: enable by setting param "shownavbar" */
.admin-page-nav { margin:0 0 1em 0;padding:4px 1em 4px 0; border-bottom:2px solid #eeeeee;}
.admin-page-nav ul { list-type: none; float:left; width: auto; margin: 4px 1em 0 0; padding:8px 0 0 0;}
.admin-page-nav ul li { display: inline; padding: 4px 0 0 0; margin: 0 4px 0 0;}
.admin-page-nav ul li a {padding: 4px 8px; background-color:#dddddd; color:black;}
.admin-page-nav ul li span.admin-no-link {padding: 4px 8px; background-color:#999999; color:#ffffff;}
.admin-page-nav ul li a:hover {background-color:#000; color: #fff; text-decoration:none;}
.admin-nav-clear { clear:both; margin: 0; padding:0; width:100%; height: 1px; }
//--></style>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title><?=$title?></title>
</head>
<body>
<?php
}

// Footer at bottom
function admin_html_footer() {
?>
</body>
</html>
<?php
}

// Set colours and details of rendering here
function admin_render_form($form) {
    //$form->display();
    //return;
    $renderer =& $form->defaultRenderer();

    $form->setRequiredNote('<font color="#FF0000">*</font> shows the required fields.');
    $form->setJsWarnings('Those fields have errors :', 'Thanks for correcting them.');

    $renderer->setFormTemplate('<form{attributes}><table width="100%" border="0" cellpadding="3" cellspacing="2" bgcolor="#CCCC99">{content}</table></form>');
    $renderer->setHeaderTemplate('<tr><td style="white-space:nowrap;background:#996;color:#ffc;" align="left" colspan="2"><b>{header}</b></td></tr>');

// Use for labels on specific groups:
//    $renderer->setGroupTemplate('<table><tr>{content}</tr></table>', ***);
//    $renderer->setGroupElementTemplate('<td>{element}<br /><span style="font-size:10px;"><!-- BEGIN required --><span style="color: #f00">*</span><!-- END required --><span style="color:#996;">{label}</span></span></td>', ***);

    $form->accept($renderer);
    echo $renderer->toHtml();
}

function make_ids_links($text) {
    $text = htmlspecialchars($text);
    // Message ids e.g. 0361593135850d75745e
    $text = preg_replace("/([a-f0-9]{20})/",
            "<a href=\"?page=fyrqueue&id=\$1\">\$1</a>",
            $text);
    // Ratty rules e.g. rule #10
    $text = preg_replace("/rule #([0-9]+)/",
            "<a href=\"?page=ratty-fyr-abuse&action=editrule&rule_id=\$1\">rule #\$1</a>",
            $text);
    $text = preg_replace('#Ticket (\d+)#i',
            '<a href="https://secure.mysociety.org/rt/Ticket/Display.html?id=$1">Ticket $1</a>',
	    $text);
    return $text;
}

?>
