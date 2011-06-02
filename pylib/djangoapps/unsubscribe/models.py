# models.py:
# A mixin for models to be used for implementing unsubscribing
#
# Copyright (c) 2011 UK Citizens Online Democracy. All rights reserved.
# Email: duncan@mysociety.org; WWW: http://www.mysociety.org/

import hashlib

from django.core.urlresolvers import reverse

import settings

class Unsubscribeable(object):
    """A mixin for implementing unsubscribing on a model.

    On a model representing an email that you want people to be able to
    unsubscribe from, subclass from this.

    """

    # The template used for the success page following an unsubscribe.
    # Override this in the model.
    unsubscribe_success_template = None

    # The template used for the unsubscribe confirmation email message.
    # Override this in the model if you want to provide something better.
    unsubscribe_confirmation_template = 'unsubscribe/confirmation.txt'

    # This will be used as the subject in the email confirming an unsubscribe
    # We're probably going to want to make this a bit more sophisticated at 
    # some point, though you could always override it with a property in
    # the model.
    unsubscribe_email_subject = 'You have been unsubscribed'

    # By default, we're expecting the email address to be in a field 'email'.
    # If the address is stored in a field with some other name, override
    # in the model.
    email_address_field = 'email'

    instance_namespace = 'unsubscribe'

    def get_unsubscribe_url(self):
        """Get a URL for unsubscribing from this model."""
        return reverse(
            'unsubscribe:unsubscribe', 
            kwargs=dict(object_id=self.id, digest=self.get_digest()), 
            current_app=self.instance_namespace,
            )

    def get_digest(self):
        """Get a digest of the model's id and a secret.

        Used for making sure that the unsubscribe link really came from
        an email, and wasn't just guessed. This should help avoid people
        unsubscribing each other. Note that if someone forwards an email
        with a valid unsubscribe link in it to someone else, that link
        is usable. If the link is clicked, we send an email to the subscriber,
        so they'll know if someone unsubscribes on their behalf.

        """
        m = hashlib.sha1()
        m.update("%s%s" %(self.id, settings.SECRET_KEY))
        return m.hexdigest()

    def get_success_template_context(self):
        """Get context for the unsubscribe success template.

        Override in your model.

        """
        return {}

    def get_confirmation_email_context(self):
        """Get context for the template for unsubscribe confirm email.

        Extend or override in your model.

        """
        return {'email': getattr(self, self.email_address_field)}
