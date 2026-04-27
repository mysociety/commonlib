"""Middleware for changing how redirects happen."""

import urlparse
import logging

from django.http import HttpResponseRedirect
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured


class FullyQualifiedRedirectMiddleware(object):
    def process_response(self, request, response):
        """Makes all redirects include a scheme and a domain.

        Takes a request and a response (as any response middleware must,
        and checks to see if the response is a redirect. If so, and
        if location or scheme is missing, indication a redirect with
        just a path, adds in the scheme and domain so that the URL
        is fully qualified.
        """

        if isinstance(response, HttpResponseRedirect):
            logging.debug('Location: %s', response['Location'])
            parsed_location = urlparse.urlparse(response['Location'])

            if not (parsed_location.scheme and parsed_location.netloc):
                new_location = list(parsed_location)

                new_location[0] = 'https' if self.request_is_secure(request) else 'http'
                new_location[1] = request.get_host()
                new_location[2] = urlparse.urljoin(request.META['PATH_INFO'], parsed_location.path)

                response['Location'] = urlparse.urlunparse(new_location)

        return response

    def request_is_secure(self, request):
        """Check if a request is secure"""
        # From Django 1.4 onwards request.is_secure() takes care of identifying
        # secure requests forwarded via a proxy, by checking the header given
        # in the SECURE_PROXY_SSL_HEADER setting.
        # See: https://docs.djangoproject.com/en/1.4/ref/settings/#secure-proxy-ssl-header
        # Older versions would always return false if the request was being
        # forwarded by a proxy, since they would see only http.
        # Therefore, we duplicate the functionality from:
        # https://github.com/django/django/blob/master/django/http/request.py
        # here, so that older versions can use the setting too.
        # Remember to set it correctly!
        if settings.SECURE_PROXY_SSL_HEADER:
            try:
                header, value = settings.SECURE_PROXY_SSL_HEADER
            except ValueError:
                raise ImproperlyConfigured('The SECURE_PROXY_SSL_HEADER setting must be a tuple containing two values.')
            if request.META.get(header, None) == value:
                return True
        else:
            return request.is_secure()
