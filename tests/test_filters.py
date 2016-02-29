from .common import *

from av.filter import Filter


class TestFilters(TestCase):

    def test_filter_descriptors(self):

        f = Filter('mandelbrot')
        self.assertEqual(f.name, 'mandelbrot')
        self.assertEqual(f.description, 'Render a Mandelbrot fractal.')
        self.assertEqual(len(f.inputs), 0)
        self.assertEqual(len(f.outputs), 1)
        self.assertEqual(f.outputs[0].name, 'default')
        self.assertEqual(f.outputs[0].type, 'video')
        