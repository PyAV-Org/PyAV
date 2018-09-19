# coding: utf8

import os
import sys
import unittest

from .common import *

# On Windows, Python 3.0 - 3.5 have issues handling unicode filenames.
# Starting with Python 3.6 the situation is saner thanks to PEP 529:
#
# https://www.python.org/dev/peps/pep-0529/

broken_unicode = (
    os.name == 'nt' and
    sys.version_info >= (3, 0) and
    sys.version_info < (3, 6))


class TestContainers(TestCase):

    @unittest.skipIf(broken_unicode, 'Unicode filename handling is broken')
    def test_unicode_filename(self):

        container = av.open(self.sandboxed(u'¢∞§¶•ªº.mov'), 'w')
