import random, hmac, hashlib
from django.db import models
from django.conf import settings
from django.contrib.contenttypes.models import ContentType
from django.contrib.contenttypes import generic
from django.core.urlresolvers import reverse
from utils import int_to_base32, base32_to_int, send_email

class EmailConfirmation(models.Model):
    class Meta:
        abstract = True

    confirmed = models.BooleanField(default=False)

    # Override these in the superclass
    after_confirm = None
    after_unsubscribe = None

    def confirm(self, email_template):
        send_email(
            "Alert confirmation",
            email_template,
            {
                'object': self,
                'id': int_to_base32(self.id),
                'token': self.make_token(random.randint(0,32767)),
            }, self.email # The superclass must have an email field
        )

    @models.permalink
    def url_after_confirm(self):
        return (self.after_confirm, [ self.id ])

    @models.permalink
    def url_after_unsubscribe(self):
        return (self.after_unsubscribe, [ self.id ])

    def path_for_unsubscribe(self):
        return reverse('emailconfirmation-unsubscribe', kwargs={
            'id': int_to_base32(self.id),
            'token': self.make_token(random.randint(0,32767)),
        })

    def check_token(self, token):
        try:
            rand, hash = token.split("-")
        except:
            return False

        try:
            rand = base32_to_int(rand)
        except:
            return False

        if self.make_token(rand) != token:
            return False

        return True

    def make_token(self, rand):
        rand = int_to_base32(rand)
        hash = hmac.new(settings.SECRET_KEY, unicode(self.id) + rand, hashlib.sha1).hexdigest()[::2]
        return "%s-%s" % (rand, hash)
