"""
Simple audio filtering example ported from C code:
   https://github.com/FFmpeg/FFmpeg/blob/master/doc/examples/filter_audio.c
"""
from fractions import Fraction
import hashlib
import sys

import numpy as np

import av
import av.audio.frame as af
import av.filter


FRAME_SIZE = 1024

INPUT_SAMPLE_RATE = 48000
INPUT_FORMAT = 'fltp'
INPUT_CHANNEL_LAYOUT = '5.0(side)'  # -> AV_CH_LAYOUT_5POINT0

OUTPUT_SAMPLE_RATE = 44100
OUTPUT_FORMAT = 's16'  # notice, packed audio format, expect only one plane in output
OUTPUT_CHANNEL_LAYOUT = 'stereo'  # -> AV_CH_LAYOUT_STEREO

VOLUME_VAL = 0.90


def init_filter_graph():
    graph = av.filter.Graph()

    output_format = 'sample_fmts={}:sample_rates={}:channel_layouts={}'.format(
        OUTPUT_FORMAT,
        OUTPUT_SAMPLE_RATE,
        OUTPUT_CHANNEL_LAYOUT
    )
    print(f'Output format: {output_format}')

    # initialize filters
    filter_chain = [
        graph.add_abuffer(format=INPUT_FORMAT,
                          sample_rate=INPUT_SAMPLE_RATE,
                          layout=INPUT_CHANNEL_LAYOUT,
                          time_base=Fraction(1, INPUT_SAMPLE_RATE)),
        # initialize filter with keyword parameters
        graph.add('volume', volume=str(VOLUME_VAL)),
        # or compound string configuration
        graph.add('aformat', output_format),
        graph.add('abuffersink')
    ]

    # link up the filters into a chain
    print('Filter graph:')
    for c, n in zip(filter_chain, filter_chain[1:]):
        print(f'\t{c} -> {n}')
        c.link_to(n)

    # initialize the filter graph
    graph.configure()

    return graph


def get_input(frame_num):
    """
    Manually construct and update AudioFrame.
    Consider using AudioFrame.from_ndarry for most real life numpy->AudioFrame conversions.

    :param frame_num:
    :return:
    """
    frame = av.AudioFrame(format=INPUT_FORMAT, layout=INPUT_CHANNEL_LAYOUT, samples=FRAME_SIZE)
    frame.sample_rate = INPUT_SAMPLE_RATE
    frame.pts = frame_num * FRAME_SIZE

    for i in range(len(frame.layout.channels)):
        data = np.zeros(FRAME_SIZE, dtype=af.format_dtypes[INPUT_FORMAT])
        for j in range(FRAME_SIZE):
            data[j] = np.sin(2 * np.pi * (frame_num + j) * (i + 1) / float(FRAME_SIZE))
        frame.planes[i].update(data)

    return frame


def process_output(frame):
    data = frame.to_ndarray()
    for i in range(data.shape[0]):
        m = hashlib.md5(data[i, :].tobytes())
        print(f'Plane: {i:0d} checksum: {m.hexdigest()}')


def main(duration):
    frames_count = int(duration * INPUT_SAMPLE_RATE / FRAME_SIZE)

    graph = init_filter_graph()

    for f in range(frames_count):
        frame = get_input(f)

        # submit the frame for processing
        graph.push(frame)

        # pull frames from graph until graph has done processing or is waiting for a new input
        while True:
            try:
                out_frame = graph.pull()
                process_output(out_frame)
            except (BlockingIOError, av.EOFError):
                break

    # process any remaining buffered frames
    while True:
        try:
            out_frame = graph.pull()
            process_output(out_frame)
        except (BlockingIOError, av.EOFError):
            break


if __name__ == '__main__':
    duration = 1.0 if len(sys.argv) < 2 else float(sys.argv[1])
    main(duration)
