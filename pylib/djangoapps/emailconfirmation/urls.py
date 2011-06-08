from django.conf.urls.defaults import *

# When including these urls, specify model_type to be the class of the model
# which is superclassing EmailConfirmation, for example
# urlpatterns = patterns('',
#     (r'^/', include('emailconfirmation'), {'model_type': Alert}),
# )

urlpatterns = patterns('emailconfirmation.views',
    url(r'^C/(?P<id>[0-9A-Za-z]+)-(?P<token>.+)$', 'confirm', name='emailconfirmation-confirm'),
    url(r'^D/(?P<id>[0-9A-Za-z]+)-(?P<token>.+)$', 'unsubscribe', name='emailconfirmation-unsubscribe'),
)

