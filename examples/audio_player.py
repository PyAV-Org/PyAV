import array
import argparse
import sys
import pprint
import subprocess
import time

from PyQt4 import QtCore, QtGui, QtMultimedia as QtMm

import av


parser = argparse.ArgumentParser()
parser.add_argument('path')
args = parser.parse_args()

container = av.open(args.path)
stream = next(s for s in container.streams if s.type == 'audio')

fifo = av.AudioFifo()
resampler = av.AudioResampler(
    format=av.AudioFormat('s16').packed,
    layout='mono',
    rate=48000,
)



qformat = QtMm.QAudioFormat()
qformat.setByteOrder(QtMm.QAudioFormat.LittleEndian)
qformat.setChannelCount(1)
qformat.setCodec('audio/pcm')
qformat.setSampleRate(48000)
qformat.setSampleSize(16)
qformat.setSampleType(QtMm.QAudioFormat.SignedInt)

output = QtMm.QAudioOutput(qformat)
output.setBufferSize(16 * 48000)

device = output.start()

print qformat, output, device

for pi, packet in enumerate(container.demux(stream)):
    for fi, frame in enumerate(packet.decode()):

        frame = resampler.resample(frame)
        print pi, fi, frame

        data = frame.planes[0].to_bytes()
        while data:
            written = device.write(data)
            if written:
                print 'wrote', written
                data = data[written:]
            else:
                print 'did not accept data; sleeping'
                time.sleep(0.033)
