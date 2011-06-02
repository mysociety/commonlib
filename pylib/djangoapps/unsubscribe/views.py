# views.py:
# Views for unsubscribing from some sort of email
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: duncan@mysociety.org; WWW: http://www.mysociety.org/

from django.http import Http404
from django.shortcuts import render_to_response

import settings

def unsubscribe(request, 
                # Set these arguments in urls.py
                model=None,
                # Reverse the url on these arguments
                object_id=None, digest=None,
                ):
    """View to use when someone clicks an unsubscribe link.

    The model keyword argument should be populated where the unsubscribe
    urls are included into the project's urls - see the documentation for
    this app's urls module.

    object_id and digest should come from the url.

    """

    try:
        row = model.objects.get(id=object_id)
    except model.DoesNotExist:
        raise Http404

    if not row.get_digest() == digest:
        raise Http404

    context = row.get_success_template_context()
    email_context = row.get_confirmation_email_context()
    row.delete()

    # Email to confirm unsubscription
    send_email(request, 
               model.unsubscribe_email_subject,
               model.unsubscribe_confirmation_template,
               email_context,
               (getattr(row, model.email_address_field),)
               )

    return render_to_response(model.unsubscribe_success_template, context)


# FIXME - Copied from EmailConfirmation - we should share
from django.template import loader, Context
from django.core.mail import send_mail

def send_email(request, subject, template, context, to):
    t = loader.get_template(template)
    if request:
        context.update({
            'host': request.META['HTTP_HOST'],
        })
    mail = t.render(Context(context))
    send_mail(subject, mail, settings.DEFAULT_FROM_EMAIL, [to])
