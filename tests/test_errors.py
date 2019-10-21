import av

from .common import TestCase, is_py33, is_windows


class TestErrorBasics(TestCase):

    def test_filenotfound(self):

        errcls = FileNotFoundError if is_py33 else OSError
        try:
            av.open('does not exist')
        except errcls as e:
            self.assertEqual(e.errno, 2)
            if is_windows:
                self.assertTrue(e.strerror in ['Error number -2 occurred',
                                               'No such file or directory'])
            else:
                self.assertEqual(e.strerror, 'No such file or directory')
            self.assertEqual(e.filename, 'does not exist')
        else:
            self.fail('no exception raised')

    def test_buffertoosmall(self):

        try:
            av.error.err_check(-av.error.BUFFER_TOO_SMALL.value)
        except av.BufferTooSmallError as e:
            self.assertEqual(e.errno, av.error.BUFFER_TOO_SMALL.value)
        else:
            self.fail('no exception raised')
