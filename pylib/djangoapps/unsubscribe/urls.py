# urls.py:
# Urls to include in your app for unsubscribe functionality
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: duncan@mysociety.org; WWW: http://www.mysociety.org/

"""Urls for include somewhere in your django project.

Include this urls file somewhere, perhaps under 'unsubscribe', passing in the
model representing the email which is being unsubscribed from in the keyword
arguments.

urlpatterns += (
    (r'^unsubscribe/', include('unsubscribe.urls'), 
      {'model': binalerts.models.CollectionAlert, 
       'success_template': 'alert_unsubscribed.html'}),
    )

"""

from django.conf.urls.defaults import patterns, url

urlpatterns = patterns('unsubscribe.views',
     url(r'(?P<object_id>\d+)/(?P<digest>[^/]+)/', 'unsubscribe', name='unsubscribe'),
)
