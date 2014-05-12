#!/usr/bin/env python

import subprocess
import optparse
import os
import sys

def which(program):
    import os
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)
    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file

    return None
    
ffmpeg_cmd = None
avconv_cmd = None

if which('ffmpeg'):
    ffmpeg_cmd = [which('ffmpeg'), '-y', '-f', 'lavfi', '-i']
if which('avconv'):
    avconv_cmd = [which('avconv'),'-y', '-filter_complex']
    
if not ffmpeg_cmd and not avconv_cmd:
    print 'Unable to find ffmpeg or avconve command'
    sys.exit(-1)

def testsrc(size, frame_rate, time, out_path, vcodec=None, bitrate=None, pix_fmt=None, use_avconv=False):
    exec_cmd = ffmpeg_cmd
    if use_avconv or os.environ.get('LIBRARY', None) == 'libav':
        exec_cmd = avconv_cmd
    
    exec_cmd.extend(['testsrc=size=%s:rate=%s' % (size, str(frame_rate)), '-t', str(time)])
    
    if vcodec:
        exec_cmd.extend(['-vcodec',vcodec])
        
    if bitrate:
        exec_cmd.extend(['-b', str(bitrate)])
    
    if pix_fmt:
        exec_cmd.extend(['-pix_fmt', pix_fmt])
        
    exec_cmd.extend([out_path])
    print subprocess.list2cmdline(exec_cmd)
    subprocess.check_call(exec_cmd)

def main():
    parser = optparse.OptionParser()
    parser.add_option('-r', '--rate', help="Frame Rate", default=24, type="string")
    parser.add_option('-t', '--time', help="Duration in seconds.", default=5, type="int")
    parser.add_option('-s', '--size', help="size of testsrc", default='640x480')
    parser.add_option('-v', '--vcodec', help="video codec", default='mpeg4')
    parser.add_option('-b', '--bitrate', help="video bitrate")
    parser.add_option('-p', '--pix_fmt', help='pixel format')
    parser.add_option('--use_avconv', help="force using avconv",action="store_true", default=False)
 
    (options, args) = parser.parse_args()

    if not args:
        parser.error("not enough args")
        
    testsrc(options.size, 
            options.rate, 
            options.time, 
            args[0],
            options.vcodec,
            options.bitrate,
            options.pix_fmt,
            use_avconv=options.use_avconv)
    
    
if __name__ == "__main__":
    main()
