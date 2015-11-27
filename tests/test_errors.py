from .common import *


class TestErrorBasics(TestCase):

    def test_error_attributes(self):
        try:
            av.open('does not exist')
        except AVError as e:
            self.assertEqual(e.errno, 2)
            if is_windows:
                self.assertEqual(e.strerror, 'Error number -2 occurred')
            else:
                self.assertEqual(e.strerror, 'No such file or directory')
            self.assertEqual(e.filename, 'does not exist')
        else:
            self.fail('no exception raised')

