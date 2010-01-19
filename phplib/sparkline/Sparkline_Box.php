<?php
/*
 * Sparkline_Box.php:
 * Simple box plot for WTT stats
 * 
 * Copyright (c) 2006 UK Citizens Online Democracy. All rights reserved.
 * Email: matthew@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: Sparkline_Box.php,v 1.1 2006-02-12 20:46:09 matthew Exp $
 * 
 */

require_once('Sparkline.php');

class Sparkline_Box extends Sparkline {
  var $min = 0; var $max = 1;
  var $width = 200; # doesn't include padding 2 left, 7 right
  var $mean; var $low; var $high;

  function Sparkline_Box($mean, $low, $high, $catch_errors = true) {
    parent::Sparkline($catch_errors);
    $this->mean = $mean;
    $this->low = $low;
    $this->high = $high;
    $this->render(13);
  }

  function render($y) { # $y is height of box plot
    $h = imagefontheight(FONT_1) + 2; # Gap at bottom and top
    $w = imagefontwidth(FONT_1);
    $yy = $y + 2*$h; # $yy is height of image
    if (!parent::Init($this->width+10, $yy)) {
      return false;
    }
    $this->DrawBackground();
    $this->DrawLine(2, $h, 2, $yy-$h-1, 'black');
    $this->DrawLine(2, floor($y/2)+$h, 2+$this->width, floor($y/2)+$h, 'black');
    $this->DrawLine(2+$this->width, $h, 2+$this->width, $yy-$h-1, 'black');
    $this->DrawTextRelative('0', 0, 0, 'black', TEXT_RIGHT, 0);
    $this->DrawTextRelative('100', $this->width+10, 0, 'black', TEXT_LEFT, 0);
    $this->DrawRectangle(2+$this->low*$this->width, $h, 2+$this->high*$this->width, $yy-$h-1, 'grey');
    $this->DrawLine(2+$this->mean*$this->width, $h, 2+$this->mean*$this->width, $yy-$h-1, 'red');
    $mean = round($this->mean*100, 1) . '%';
    $this->DrawTextRelative($mean, 2+$this->mean*$this->width, $yy-1, 'red', TEXT_TOP, 0);
  }
}

?>
