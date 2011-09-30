from django.http import Http404, HttpResponseRedirect
from django.shortcuts import get_object_or_404
from utils import base32_to_int

def confirm(request, id, token, model_type=None):
    try:
        id = base32_to_int(id)
    except ValueError:
        raise Http404

    confirmation = get_object_or_404(model_type, id=id)
    if confirmation.check_token(token):
        confirmation.confirmed = True
        confirmation.save()
        return HttpResponseRedirect(confirmation.url_after_confirm())
    return HttpResponseRedirect('/')

def unsubscribe(request, id, token, model_type=None):
    try:
        id = base32_to_int(id)
    except ValueError:
        raise Http404

    confirmation = get_object_or_404(model_type, id=id)
    if confirmation.check_token(token):
        confirmation.confirmed = False
        confirmation.save()
        return HttpResponseRedirect(confirmation.url_after_unsubscribe())
    return HttpResponseRedirect('/')

