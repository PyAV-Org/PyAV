#!/usr/bin/env python
import sys
import wave
import math
import struct
import random
import optparse

try:
    from itertools import izip, count, islice, imap, izip_longest
except ImportError:
    from itertools import count, zip_longest as izip_longest
    izip = zip
    islice = slice
    imap = map

try:
    xrange
except NameError:
    xrange = range


def grouper(n, iterable, fillvalue=None):
    "grouper(3, 'ABCDEFG', 'x') --> ABC DEF Gxx"
    args = [iter(iterable)] * n
    return izip_longest(fillvalue=fillvalue, *args)

def sine_wave(frequency=440.0, framerate=44100, amplitude=0.5):
    '''
    Generate a sine wave at a given frequency of infinite length.
    '''
    period = int(framerate / frequency)
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    lookup_table = [float(amplitude) * math.sin(2.0*math.pi*float(frequency)*(float(i%period)/float(framerate))) for i in xrange(period)]
    return (lookup_table[i%period] for i in count(0))

def square_wave(frequency=440.0, framerate=44100, amplitude=0.5):
    for s in sine_wave(frequency, framerate, amplitude):
        if s > 0:
            yield amplitude
        elif s < 0:
            yield -amplitude
        else:
            yield 0.0

def damped_wave(frequency=440.0, framerate=44100, amplitude=0.5, length=44100):
    if amplitude > 1.0: amplitude = 1.0
    if amplitude < 0.0: amplitude = 0.0
    return (math.exp(-(float(i%length)/float(framerate))) * s for i, s in enumerate(sine_wave(frequency, framerate, amplitude)))

def white_noise(amplitude=0.5):
    '''
    Generate random samples.
    '''
    return (float(amplitude) * random.uniform(-1, 1) for i in count(0))

def compute_samples(channels, nsamples=None):
    '''
    create a generator which computes the samples.

    essentially it creates a sequence of the sum of each function in the channel
    at each sample in the file for each channel.
    '''
    return islice(izip(*(imap(sum, izip(*channel)) for channel in channels)), nsamples)

def write_wavefile(filename, samples, nframes=None, nchannels=2, sampwidth=2, framerate=44100, bufsize=2048):
    "Write samples to a wavefile."
    if nframes is None:
        nframes = -1

    w = wave.open(filename, 'w')
    w.setparams((nchannels, sampwidth, framerate, nframes, 'NONE', 'not compressed'))

    max_amplitude = float(int((2 ** (sampwidth * 8)) / 2) - 1)

    # split the samples into chunks (to reduce memory consumption and improve performance)
    for chunk in grouper(bufsize, samples):
        frames = b''.join(b''.join(struct.pack('h', int(max_amplitude * sample)) for sample in channels) for channels in chunk if channels is not None)
        w.writeframesraw(frames)
    
    w.close()

    return filename

def write_pcm(f, samples, sampwidth=2, framerate=44100, bufsize=2048):
    "Write samples as raw PCM data."
    max_amplitude = float(int((2 ** (sampwidth * 8)) / 2) - 1)

    # split the samples into chunks (to reduce memory consumption and improve performance)
    for chunk in grouper(bufsize, samples):
        frames = b''.join(b''.join(struct.pack('h', int(max_amplitude * sample)) for sample in channels) for channels in chunk if channels is not None)
        f.write(frames)
    
    f.close()

    return filename

def main():
    parser = optparse.OptionParser()
    parser.add_option('-c', '--channels', help="Number of channels to produce", default=2, type="int")
    parser.add_option('-b', '--bits', help="Number of bits in each sample", default=16, type="int")
    parser.add_option('-r', '--rate', help="Sample rate in Hz", default=44100, type="int")
    parser.add_option('-t', '--time', help="Duration of the wave in seconds.", default=60, type="int")
    parser.add_option('-a', '--amplitude', help="Amplitude of the wave on a scale of 0.0-1.0.", default=0.5, type="float")
    parser.add_option('-f', '--frequency', help="Frequency of the wave in Hz", default=440.0, type="float")
 
    (options, args) = parser.parse_args()

    if not args:
        parser.error("not enough args")

    # each channel is defined by infinite functions which are added to produce a sample.
    channels = ((sine_wave(options.frequency, options.rate, options.amplitude),) for i in range(options.channels))

    # convert the channel functions into waveforms
    samples = compute_samples(channels, options.rate * options.time)

    # write the samples to a file
    if args[0] == '-':
        filename = sys.stdout
    else:
        filename = args[0]
    write_wavefile(filename, samples, options.rate * options.time, options.channels, options.bits / 8, options.rate)

if __name__ == "__main__":
    main()
