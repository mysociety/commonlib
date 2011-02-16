from django.conf.urls.defaults import *

urlpatterns = patterns('emailconfirmation.views',
    url(r'^C/(?P<id>[0-9A-Za-z]+)-(?P<token>.+)$', 'confirm', name='emailconfirmation-confirm'),
    url(r'^D/(?P<id>[0-9A-Za-z]+)-(?P<token>.+)$', 'unsubscribe', name='emailconfirmation-unsubscribe'),
)

