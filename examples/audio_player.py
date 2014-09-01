import array
import argparse
import sys
import pprint
import subprocess
import time

from qtproxy import Q

import av


parser = argparse.ArgumentParser()
parser.add_argument('path')
args = parser.parse_args()

container = av.open(args.path)
stream = next(s for s in container.streams if s.type == 'audio')

fifo = av.AudioFifo()
resampler = av.AudioResampler(
    format=av.AudioFormat('s16').packed,
    layout='stereo',
    rate=48000,
)



qformat = Q.AudioFormat()
qformat.setByteOrder(Q.AudioFormat.LittleEndian)
qformat.setChannelCount(2)
qformat.setCodec('audio/pcm')
qformat.setSampleRate(48000)
qformat.setSampleSize(16)
qformat.setSampleType(Q.AudioFormat.SignedInt)

output = Q.AudioOutput(qformat)
output.setBufferSize(2 * 2 * 48000)

device = output.start()

print qformat, output, device

def decode_iter():
    try:
        for pi, packet in enumerate(container.demux(stream)):
            for fi, frame in enumerate(packet.decode()):
                yield pi, fi, frame
    except:
        return

for pi, fi, frame in decode_iter():

    frame = resampler.resample(frame)
    print pi, fi, frame, output.state()
    
    bytes_buffered = output.bufferSize() - output.bytesFree()
    us_processed = output.processedUSecs()
    us_buffered = 1000000 * bytes_buffered / (2 * 16 / 8) / 48000
    print 'pts: %.3f, played: %.3f, buffered: %.3f' % (frame.time or 0, us_processed / 1000000.0, us_buffered / 1000000.0)


    data = frame.planes[0].to_bytes()
    while data:
        written = device.write(data)
        if written:
            # print 'wrote', written
            data = data[written:]
        else:
            # print 'did not accept data; sleeping'
            time.sleep(0.033)

    if False and pi % 100 == 0:
        output.reset()
        print output.state(), output.error()
        device = output.start()

    # time.sleep(0.05)

while output.state() == Q.Audio.ActiveState:
    time.sleep(0.1)