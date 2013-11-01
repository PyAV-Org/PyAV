import datetime
import errno
import os
from unittest import TestCase as _Base

import av
from av.frame import Frame
from av.packet import Packet
from av.stream import Stream
from av.utils import AVError


def makedirs(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise


_start_time = datetime.datetime.now()

def _sandbox():
    root = os.path.abspath(os.path.join(
        __file__, '..', '..',
        'sandbox'
    ))
    sandbox = os.path.join(
        root,
        _start_time.strftime('%Y%m%d-%H%M%S'),
    )
    if not os.path.exists(sandbox):
        os.makedirs(sandbox)
        last = os.path.join(root, 'last')
        try:
            os.unlink(last)
        except OSError:
            pass
        os.symlink(sandbox, last)
    return sandbox


def sandboxed(*args, **kwargs):
    do_makedirs = kwargs.pop('makedirs', True)
    base = kwargs.pop('sandbox', None)
    if kwargs:
        raise TypeError('extra kwargs: %s' % ', '.join(sorted(kwargs)))
    path = os.path.join(_sandbox() if base is None else base, *args)
    if do_makedirs:
        makedirs(os.path.dirname(path))
    return path


class TestCase(_Base):

    @classmethod
    def _sandbox(cls):
        path = os.path.join(_sandbox(), cls.__name__)
        try:
            os.makedirs(path)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise
        return path

    @property
    def sandbox(self):
        return self._sandbox()

    def sandboxed(self, *args, **kwargs):
        kwargs.setdefault('sandbox', self.sandbox)
        return sandboxed(*args, **kwargs)


