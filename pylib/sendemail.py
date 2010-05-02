# email.py:
# Functions for sending email
#
# Copyright (c) 2009 UK Citizens Online Democracy. All rights reserved.
# Email: matthew@mysociety.org; WWW: http://www.mysociety.org/
#
# $Id: sendemail.py,v 1.5 2009/12/17 17:31:04 francis dead $
#

import re, smtplib
from minimock import mock, Mock
from email.message import Message
from email.header import Header
from email.utils import formataddr, make_msgid, formatdate
from email.charset import Charset, QP

charset = Charset('utf-8')
charset.body_encoding = QP

def send_email(sender, to, message, headers={}):
    """Sends MESSAGE from SENDER to TO, with HEADERS
    Returns True if successful, False if not
    
    >>> mock('smtplib.SMTP', returns=Mock('smtp_connection'))
    >>> send_email("a@b.c", "d@e.f", "Hello, this is a message!", {
    ...     'Subject': 'Mapumental message',
    ...     'From': ("a@b.c", "Ms. A"),
    ...     'To': "d@e.f"
    ... }) # doctest:+ELLIPSIS
    Called smtplib.SMTP('localhost')
    Called smtp_connection.sendmail(
        'a@b.c',
        'd@e.f',
        'MIME-Version: 1.0\\nContent-Type: text/plain; charset="utf-8"\\nContent-Transfer-Encoding: quoted-printable\\nMessage-ID: <...>\\nDate: ...\\nTo: d@e.f\\nFrom: "Ms. A" <a@b.c>\\nSubject: Mapumental message\\n\\nHello, this is a message!')
    Called smtp_connection.quit()
    True
    """

    message = re.sub('\r\n', '\n', message)

    msg = Message()
    msg.set_payload(message, charset)
    msg['Message-ID'] = make_msgid()
    msg['Date'] = formatdate(localtime=True)

    for key, value in headers.items():
        if isinstance(value, tuple):
            email = re.sub('\r|\n', ' ', value[0])
            name = re.sub('\r|\n', ' ', value[1])
            if isinstance(name, str):
                name = unicode(name, 'utf-8')
            name = Header(name, 'utf-8')
            msg[key] = formataddr((str(name), email))
        else:
            value = re.sub('\r|\n', ' ', value)
            if isinstance(value, str):
                value = unicode(value, 'utf-8')
            msg[key] = Header(value, 'utf-8')

    success = True
    server = smtplib.SMTP('localhost')
    try:
        server.sendmail(sender, to, msg.as_string())
    except smtplib.SMTPResponseException, e:
        success = False
    finally:
        server.quit()
    return success

