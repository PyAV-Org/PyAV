from .common import *

from av.dictionary import Dictionary


class TestDictionary(TestCase):

    def test_basics(self):

        d = Dictionary()
        d['key'] = 'value'

        self.assertEqual(d['key'], 'value')
        self.assertIn('key', d)
        self.assertEqual(len(d), 1)
        self.assertEqual(list(d), ['key'])

        self.assertEqual(d.pop('key'), 'value')
        self.assertRaises(KeyError, d.pop, 'key')
        self.assertEqual(len(d), 0)
        
