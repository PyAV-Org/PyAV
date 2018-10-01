import warnings

from av.deprecation import renamed_attr

from .common import *


class TestDeprecations(TestCase):

    def test_renamed_attr(self):

        class Example(object):

            new_value = 'foo'
            old_value = renamed_attr('new_value')
            
            def new_func(self, a, b):
                return a + b
                
            old_func = renamed_attr('new_func')

        obj = Example()

        with warnings.catch_warnings(record=True) as captured:

            self.assertEqual(obj.old_value, 'foo')
            self.assertIn('Example.old_value is deprecated', captured[0].message.args[0])

            obj.old_value = 'bar'
            self.assertIn('Example.old_value is deprecated', captured[1].message.args[0])


        with warnings.catch_warnings(record=True) as captured:
            self.assertEqual(obj.old_func(1, 2), 3)
            self.assertIn('Example.old_func is deprecated', captured[0].message.args[0])
