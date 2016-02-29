from .common import *

from av.video.frame import VideoFrame
from av.filter import Graph, Filter


class TestFilters(TestCase):

    def test_filter_descriptors(self):

        f = Filter('mandelbrot')
        self.assertEqual(f.name, 'mandelbrot')
        self.assertEqual(f.description, 'Render a Mandelbrot fractal.')
        self.assertEqual(len(f.inputs), 0)
        self.assertEqual(len(f.outputs), 1)
        self.assertEqual(f.outputs[0].name, 'default')
        self.assertEqual(f.outputs[0].type, 'video')
    
    def test_generator_graph(self):
        
        graph = Graph()
        ctx = graph.add('mandelbrot')
        sink = graph.add('buffersink')
        ctx.link(0, sink, 0)
        graph.config()
        
        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)
        frame.to_image().save('sandbox/mandelbrot.png')
        