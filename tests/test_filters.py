from .common import *

from av.video.frame import VideoFrame
from av.filter import Graph, Filter


class TestFilters(TestCase):

    def test_filter_descriptor(self):

        f = Filter('testsrc')
        self.assertEqual(f.name, 'testsrc')
        self.assertEqual(f.description, 'Generate test pattern.')
        self.assertFalse(f.dynamic_inputs)
        self.assertEqual(len(f.inputs), 0)
        self.assertFalse(f.dynamic_outputs)
        self.assertEqual(len(f.outputs), 1)
        self.assertEqual(f.outputs[0].name, 'default')
        self.assertEqual(f.outputs[0].type, 'video')
    
    def test_dynamic_filter_descriptor(self):

        f = Filter('split')
        self.assertFalse(f.dynamic_inputs)
        self.assertEqual(len(f.inputs), 1)
        self.assertTrue(f.dynamic_outputs)
        self.assertEqual(len(f.outputs), 0)

    def test_generator_graph(self):
        
        graph = Graph()
        src = graph.add('testsrc')
        lutrgb = graph.add('lutrgb', "r=maxval+minval-val:g=maxval+minval-val:b=maxval+minval-val", name='invert')
        sink = graph.add('buffersink')
        src.link_to(lutrgb)
        lutrgb.link_to(sink)
        
        # pads and links
        self.assertIs(src.outputs[0].link.output, lutrgb.inputs[0])
        self.assertIs(lutrgb.inputs[0].link.input, src.outputs[0])
        
        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)
        frame.to_image().save(self.sandboxed('mandelbrot2.png'))
    
    def test_auto_find_sink(self):

        graph = Graph()
        src = graph.add('testsrc')
        src.link_to(graph.add('buffersink'))
        graph.configure()

        frame = graph.pull()
        frame.to_image().save(self.sandboxed('mandelbrot3.png'))

    def test_delegate_sink(self):

        graph = Graph()
        src = graph.add('testsrc')
        src.link_to(graph.add('buffersink'))
        graph.configure()

        print(src.outputs)
        
        frame = src.pull()
        frame.to_image().save(self.sandboxed('mandelbrot4.png'))

    def test_haldclut_graph(self):
        
        raise SkipTest()

        graph = Graph()
        
        img = Image.open(fate_suite('png1/lena-rgb24.png'))
        frame = VideoFrame.from_image(img)
        img_source = graph.add_buffer(frame)
        
        hald_img = Image.open('hald_7.png')
        hald_frame = VideoFrame.from_image(hald_img)
        hald_source = graph.add_buffer(hald_frame)
        
        try:
            hald_filter = graph.add('haldclut')
        except ValueError:
            # Not in Libav.
            raise SkipTest()

        sink = graph.add('buffersink')
        
        img_source.link(0, hald_filter, 0)
        hald_source.link(0, hald_filter, 1)
        hald_filter.link(0, sink, 0)
        graph.config()
        
        self.assertIs(img_source.outputs[0].linked_to, hald_filter.inputs[0])
        self.assertIs(hald_source.outputs[0].linked_to, hald_filter.inputs[1])
        self.assertIs(hald_filter.outputs[0].linked_to, sink.inputs[0])
        
        hald_source.push(hald_frame)
        
        img_source.push(frame)
        
        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)
        frame.to_image().save(self.sandboxed('filtered.png'))
        