# coding: utf8

from .common import *


class TestContainers(TestCase):

    def test_unicode_filename(self):

        container = av.open(self.sandboxed(u'¢∞§¶•ªº.mov'), 'w')
