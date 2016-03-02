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
        mandelbrot = graph.add('mandelbrot')
        lutrgb = graph.add('lutrgb', 'invert', "r=maxval+minval-val:g=maxval+minval-val:b=maxval+minval-val")
        sink = graph.add('buffersink')
        mandelbrot.link(0, lutrgb, 0)
        lutrgb.link(0, sink, 0)
        graph.config()
        
        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)
        frame.to_image().save('sandbox/mandelbrot2.png')
    
    def test_haldclut_graph(self):
        
        graph = Graph()
        
        img = Image.open(fate_suite('png1/lena-rgb24.png'))
        frame = VideoFrame.from_image(img)
        img_source = graph.add('buffer', 'in', "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d" % (
            frame.width, frame.height, int(frame.format),
            1, 1000,
            1, 1
        ))
        
        hald_img = Image.open('hald_7.png')
        hald_frame = VideoFrame.from_image(hald_img)
        hald_source = graph.add('buffer', 'hald', "video_size=%dx%d:pix_fmt=%d:time_base=%d/%d:pixel_aspect=%d/%d" % (
            hald_frame.width, hald_frame.height, int(hald_frame.format),
            1, 1000,
            1, 1
        ))
        
        hald_filter = graph.add('haldclut')
        sink = graph.add('buffersink')
        
        img_source.link(0, hald_filter, 0)
        hald_source.link(0, hald_filter, 1)
        hald_filter.link(0, sink, 0)
        graph.config()
        
        hald_source.push(hald_frame)
        
        img_source.push(frame)
        
        frame = sink.pull()
        self.assertIsInstance(frame, VideoFrame)
        frame.to_image().save('sandbox/filtered.png')
        