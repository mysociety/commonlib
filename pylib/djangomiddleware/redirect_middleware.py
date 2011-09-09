"""Middleware for changing how redirects happen."""

import urlparse
import logging

from django.http import HttpResponseRedirect
from django.contrib.sites.models import Site

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

                # FIXME - we can do better than hardcoding this
                new_location[0] = 'http'
                new_location[1] = Site.objects.get_current().domain
                new_location[2] = urlparse.urljoin(request.META['PATH_INFO'], parsed_location.path)
                
                response['Location'] = urlparse.urlunparse(new_location)

        return response

