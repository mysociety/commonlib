import random, hmac, hashlib
from django.db import models
from django.conf import settings
from django.contrib.contenttypes.models import ContentType
from django.contrib.contenttypes import generic
from django.core.urlresolvers import reverse
from utils import int_to_base32, base32_to_int, send_email

class EmailConfirmationManager(models.Manager):
    def confirm(self, request, object, after_confirm, after_unsubscribe):
        conf = EmailConfirmation(
            content_object=object,
            after_confirm=after_confirm,
            after_unsubscribe=after_unsubscribe,
        )
        conf.send_email(request)

    def path_for_unsubscribe(self, object):
        obj = EmailConfirmation.objects.get(content_object=object)
        return reverse('emailconfirmation-unsubscribe', kwargs={
            'id': int_to_base32(obj.id),
            'token': obj.make_token(random.randint(0,32767)),
        })

class EmailConfirmation(models.Model):
    confirmed = models.BooleanField(default=False)
    content_type = models.ForeignKey(ContentType)
    object_id = models.PositiveIntegerField()
    content_object = generic.GenericForeignKey('content_type', 'object_id')
    after_confirm = models.CharField(max_length=100)
    after_unsubscribe = models.CharField(max_length=100)

    objects = EmailConfirmationManager()

    def __unicode__(self):
        return 'Confirming of %s, %s' % (self.content_object.email, self.confirmed)

    def send_email(self, request):
        self.save()
        send_email(request, "Alert confirmation",
            'emailconfirmation/email.txt',
            {
                'object': self.content_object,
                'id': int_to_base32(self.id),
                'token': self.make_token(random.randint(0,32767)),
            }, self.content_object.email
        )

    @models.permalink
    def url_after_confirm(self):
        return (self.after_confirm, [ self.content_object.id ])

    @models.permalink
    def url_after_unsubscribe(self):
        return (self.after_unsubscribe, [ self.content_object.id ])

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
