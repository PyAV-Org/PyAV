from .common import *


class TestErrorBasics(TestCase):

    def test_error_attributes(self):
        try:
            av.open('does not exist')
        except AVError as e:
            self.assertEqual(e.errno, 2)
            self.assertEqual(e.strerror, 'No such file or directory')
            self.assertEqual(e.filename, 'does not exist')
            self.assertEqual(str(e), "[Errno 2] No such file or directory: 'does not exist'")
        else:
            self.fail('no exception raised')

