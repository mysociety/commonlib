from django.conf.urls.defaults import *

urlpatterns = patterns('emailconfirmation.views',
    url(r'^C/(?P<id>[0-9A-Za-z]+)-(?P<token>.+)$', 'check_token', name='emailconfirmation-check-token'),
)

