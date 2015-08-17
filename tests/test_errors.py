from .common import *


class TestErrorBasics(TestCase):

    def test_error_attributes(self):
        try:
            av.open('does not exist')
        except AVError as e:
            self.assertEqual(e.errno, 2)
            self.assertEqual(e.strerror, 'Error number -2 occurred')
            self.assertEqual(e.filename, 'does not exist')
        else:
            self.fail('no exception raised')

