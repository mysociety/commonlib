class BaseError(Exception):
    def __init__(self, *args):
        self.text = args[0]
        if len(args) > 1 and args[1] is not None:
            self.extradata = args[1]
        super(BaseError, self).__init__(*args)

    def __str__(self):
        return self.text


class UnknownError(BaseError):
    value = 0


class InterfaceError(BaseError):
    value = 1


class TransportError(BaseError):
    value = 2


class ProtocolError(BaseError):
    value = 3


class UserError(BaseError):
    value = 1024


SERVER = 512
MASK = 511
CODE_TO_NAME = {
    0: UnknownError,
    1: InterfaceError,
    2: TransportError,
    3: ProtocolError,
    1024: UserError,
}


def ErrorFactory(text, value=None, extra=None):
    if value is not None:
        value = int(value)
        if value >= 1024:
            return UserError(text, extra)
        value = value & MASK
        if value in CODE_TO_NAME:
            return CODE_TO_NAME[value](text, extra)
    return UnknownError(text, extra)
