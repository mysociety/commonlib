# __init__.py:
# A little Django app to help with unsubscribing from emails
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: duncan@mysociety.org; WWW: http://www.mysociety.org/

"""A little Django app to help with unsubscribing from emails.

This is for use when you have a model which represents some kind of email
subscription, and is used as a mixin. For instance:

class CollectionAlert(models.Model, Unsubscribeable):
    email = models.EmailField()
    street = models.ForeignKey(Street, null=True)

    unsubscribe_success_template = 'unsubscribe_succeeded.html'

The minimum you need to do in order to get this app working is:

1) Add it to INSTALLED_APPS in settings.py (as for any app).
2) Add Unsubscribeable as a mixin to a model which has an 'email' field.
3) Implement a template which will be used after a successful unsubscribe,
   and set the class variable unsubscribe_success_template on the model
   to point to this template.
4) Include the urls for the app in your project's urls file.

For other things that you can modify or set, take a look around the code!

"""
