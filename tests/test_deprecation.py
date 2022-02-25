import warnings

from av import deprecation

from .common import TestCase


class TestDeprecations(TestCase):
    def test_method(self):
        class Example(object):
            def __init__(self, x=100):
                self.x = x

            @deprecation.method
            def foo(self, a, b):
                return self.x + a + b

        obj = Example()

        with warnings.catch_warnings(record=True) as captured:
            self.assertEqual(obj.foo(20, b=3), 123)
            self.assertIn("Example.foo is deprecated", captured[0].message.args[0])

    def test_renamed_attr(self):
        class Example(object):

            new_value = "foo"
            old_value = deprecation.renamed_attr("new_value")

            def new_func(self, a, b):
                return a + b

            old_func = deprecation.renamed_attr("new_func")

        obj = Example()

        with warnings.catch_warnings(record=True) as captured:

            self.assertEqual(obj.old_value, "foo")
            self.assertIn(
                "Example.old_value is deprecated", captured[0].message.args[0]
            )

            obj.old_value = "bar"
            self.assertIn(
                "Example.old_value is deprecated", captured[1].message.args[0]
            )

        with warnings.catch_warnings(record=True) as captured:
            self.assertEqual(obj.old_func(1, 2), 3)
            self.assertIn("Example.old_func is deprecated", captured[0].message.args[0])
