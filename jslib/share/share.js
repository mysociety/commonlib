/*
 * share.js
 * Share This related JavaScript functions
 * 
 * Copyright (c) 2007 UK Citizens Online Democracy. All rights reserved.
 * Email: matthew@mysociety.org. WWW: http://www.mysociety.org
 *
 * $Id: share.js,v 1.1 2007-11-06 16:27:23 matthew Exp $
 * 
 */

function share(link) {
    var form = $('#share_form');
    if (!form.is(':hidden')) {
        form.hide();
        return;
    }
    var offset = $(link).offset();
    form.css('left', offset.left + 'px');
    form.css('top', (offset.top + link.offsetHeight + 3) + 'px');
    form.show();
}

function share_tab(tab) {
    if (tab == 1) {
        $('#share_tab2').removeClass();
        $('#share_tab1').addClass('selected');
        $('#share_email').hide();
        $('#share_social').show();
    } else {
        $('#share_tab1').removeClass()
        $('#share_tab2').addClass('selected');
        $('#share_social').hide();
        $('#share_email').show();
    }
}

