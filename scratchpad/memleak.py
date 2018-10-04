from __future__ import print_function
import resource
import subprocess
import os
import math
import gc
import logging
import time

import psutil



#gc.disable()
#logging.basicConfig()

proc = psutil.Process()
last = 0
def tick():
    global last
    now = proc.memory_info().rss
    print('%.2f %d' % (math.log(now, 2), now))
    last = now


print('import av', end=' ')
tick()

import av

def make_ffv1_level1(number_of_frames):

    print('Making the initial ffv1 level 1 video (ffv1_level1.nut).')
    ffmpeg_args = [
        'ffmpeg',
        '-loglevel', 'quiet', '-hide_banner',
        '-f', 'rawvideo', '-s:v', '512x424', '-pix_fmt', 'gray16le', '-i', 'pipe:0',
        '-r', '30', '-c:v', 'ffv1', '-level', '1', '-y', 'ffv1_level1.nut',
    ]

    ffmpeg = subprocess.Popen(ffmpeg_args, stdin=subprocess.PIPE)

    frame = chr(0) * 2 * 512 * 424  # Just a gray16le frame filled with zeroes

    with ffmpeg.stdin:
        # Write 10000 frames
        for i in xrange(number_of_frames):
            ffmpeg.stdin.write(frame)

    ffmpeg.wait()

def transcode_level1_to_level3():

    print('Now transcoding it to level 3 (ffv1_level3.nut).')
    ffmpeg_args = [
        'ffmpeg',
        '-loglevel', 'quiet', '-hide_banner',
        '-i', 'ffv1_level1.nut',
        '-c:v', 'ffv1', '-level', '3', '-coder', '1', '-context', '1', '-slices', '30', '-g', '300', '-y', 'ffv1_level3.nut',
    ]

    ffmpeg = subprocess.Popen(ffmpeg_args)
    ffmpeg.wait()



def decode_using_pyav():

    print('Decoding using PyAV.')
    fh = av.open('ffv1_level3.nut', 'r')
    for s in fh.streams:
        #print s, s.thread_type, s.thread_count
        #pass
        print('Thread count:', s.thread_count)
        #s.thread_count = 1
        #s.thread_type = 'frame'


    count = 0

    packet_iter = fh.demux()
    while True:

        #av.utils._debug_enter('__main__.demux')
        packet = next(packet_iter)
        #av.utils._debug_exit()

        #av.utils._debug_enter('__main__.decode')
        frames = packet.decode()
        #av.utils._debug_exit()

        for frame in frames:
            count += 1
            print(count, end=' ')
            tick()
            if not count % 100:
                gc.collect()
                #print 'GARBAGE:', gc.get_count(), len(gc.garbage)
            if count >= 10000:
                return



if __name__ == '__main__':

    if not os.path.exists('ffv1_level1.nut'):
        # Make this number sufficiently large and you'll hit swap (and hate yourself).
        # e.g. 100000, which is still less than an hour of video at 30 fps.
        make_ffv1_level1(10000)

    if not os.path.exists('ffv1_level3.nut'):
        transcode_level1_to_level3()

    print('START', end=' ')
    tick()

    #av.utils._debug_enter('__main__')
    decode_using_pyav()
    gc.collect()
    #av.utils._debug_exit()

    tick()
