import sys
import unittest

import av

from .common import TestCase, fate_suite, is_windows, skip_tests


# On Windows, Python 3.0 - 3.5 have issues handling unicode filenames.
# Starting with Python 3.6 the situation is saner thanks to PEP 529:
#
# https://www.python.org/dev/peps/pep-0529/

broken_unicode = is_windows and sys.version_info < (3, 6)


class TestContainers(TestCase):
    def test_context_manager(self):
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            self.assertEqual(container.format.long_name, "QuickTime / MOV")
            self.assertEqual(len(container.streams), 1)

    @unittest.skipIf(
        broken_unicode or "unicode_filename" in skip_tests,
        "Unicode filename handling is broken",
    )
    def test_unicode_filename(self):

        av.open(self.sandboxed("¢∞§¶•ªº.mov"), "w")
