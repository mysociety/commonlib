<?
/*
 * Infrastructure for administration pages.
 * 
 * Copyright (c) 2004 UK Citizens Online Democracy. All rights reserved.
 * Email: francis@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: admin.php,v 1.31 2005-07-12 18:33:40 francis Exp $
 * 
 */

require_once "utility.php";

require_once "HTML/QuickForm.php";
require_once "HTML/QuickForm/Rule.php";
require_once "HTML/QuickForm/Renderer/Default.php";

header("Content-Type: text/html; charset=utf-8");

// Error display
require_once "../../phplib/error.php";
function admin_display_error($num, $message, $file, $line, $context) {
    print "<p><strong>$message</strong> in $file:$line</p>";
}
err_set_handler_display('admin_display_error');

function admin_page_display($site_name, $pages) {
    // generate navigation bar
    $navlinks = "";
    foreach ($pages as $page) {
        if (isset($page)) {
            # $target = "target=\"content\" ";
            $target = "";
            if (isset($page->url)) {
                $navlinks .= "<a $target href=\"". $page->url."\">" . $page->navname. "</a><br>";
            } else {
                $navlinks .= "<a $target href=\"?page=". $page->id."\">" . $page->navname. "</a><br>";
            }
        } else {
            $navlinks .= "<br>";
        }
    }

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
        $title = $page->navname . " - $maintitle";
        admin_html_header($title);
        print "<h1>$title</h1>";
        $self_link = "?page=$id";
        $page->self_link = $self_link;
        $page->display($self_link); # TODO remove this as parameter, use class member
        admin_html_footer();
    } else/*if (get_http_var("navframe"))*/ {
        // right hand nav frame
        admin_html_header($maintitle);
?>
<h3><?=$site_name?></h3>
<?=$navlinks?>
<p><a href="http://www.mysociety.org/"><img class="mslogo" src="https://secure.mysociety.org/mysociety_sm.gif" border="0" alt="mySociety"></a></p>
<?
        admin_html_footer();
    } 
    // Turn off frames for now, as never used
    /* else {
        $url = get_http_var('url');
        if (!$url) {
            $url = "?page=" . $pages[0]->id;
        }
?><!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head><title><?=$maintitle?></title></head>
<frameset cols="*,180">
<noframes><h1><?=$maintitle?></h1><?=$navlinks?></noframes>
<frame name="content" src="<?=$url?>">
<frame name="navigation" src="?navframe=yes">
</frameset>
</html>
<?
    } */
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
.difffrom {background-color: #99ff66; }
.diffto {background-color: #99ffcc; }
.diffsnip {background-color: #ccff33; }
i {color: #666666;  background-color: #cccccc; }
img.mslogo {float: left;  border: 0px; }
hr {width: 600px;  background-color: #cccccc;  border: 0px;  height: 1px;  color: #000000; }
img.creatorpicture { float: left; display: inline; margin-right: 10px; }
.timeline dt {   clear: left; float: left; font-weight: bold; }
.timeline dd { margin-left: 8em; }
//--></style>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title><?=$title?></title>
</head>
<body>
<?
}

// Footer at bottom
function admin_html_footer() {
?>
</body>
</html>
<?
}

// Set colours and details of rendering here
function admin_render_form($form) {
    //$form->display();
    //return;
    $renderer =& $form->defaultRenderer();

    $form->setRequiredNote('<font color="#FF0000">*</font> shows the required fields.');
    $form->setJsWarnings('Those fields have errors :', 'Thanks for correcting them.');

    $renderer->setFormTemplate('<table width="100%" border="0" cellpadding="3" cellspacing="2" bgcolor="#CCCC99"><form{attributes}>{content}</form></table>');
    $renderer->setHeaderTemplate('<tr><td style="white-space:nowrap;background:#996;color:#ffc;" align="left" colspan="2"><b>{header}</b></td></tr>');

// Use for labels on specific groups:
//    $renderer->setGroupTemplate('<table><tr>{content}</tr></table>', ***);
//    $renderer->setGroupElementTemplate('<td>{element}<br /><span style="font-size:10px;"><!-- BEGIN required --><span style="color: #f00">*</span><!-- END required --><span style="color:#996;">{label}</span></span></td>', ***);

    $form->accept($renderer);
    echo $renderer->toHtml();
}

?>
