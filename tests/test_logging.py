from __future__ import division

from .common import *

import av.logging
import logging


class TestLogging(TestCase):

    def test_adapt_level(self):
        self.assertEqual(
            av.logging.adapt_level(av.logging.ERROR),
            logging.ERROR
        )
        self.assertEqual(
            av.logging.adapt_level(av.logging.WARNING),
            logging.WARNING
        )
        self.assertEqual(
            av.logging.adapt_level((av.logging.WARNING + av.logging.ERROR) // 2),
            logging.WARNING
        )

