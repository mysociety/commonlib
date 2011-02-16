from django.http import Http404, HttpResponseRedirect
from django.shortcuts import get_object_or_404
from models import EmailConfirmation
from utils import base32_to_int

def confirm(request, id, token):
    try:
        id = base32_to_int(id)
    except ValueError:
        raise Http404

    confirmation = get_object_or_404(EmailConfirmation, id=id)
    if confirmation.check_token(token):
        confirmation.confirmed = True
        confirmation.save()
        return HttpResponseRedirect(confirmation.url_after_confirm())
    return HttpResponseRedirect('/')

def unsubscribe(request, id, token):
    try:
        id = base32_to_int(id)
    except ValueError:
        raise Http404

    confirmation = get_object_or_404(EmailConfirmation, id=id)
    if confirmation.check_token(token):
        confirmation.confirmed = False
        confirmation.save()
        return HttpResponseRedirect(confirmation.url_after_unsubscribe())
    return HttpResponseRedirect('/')

