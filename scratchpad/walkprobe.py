from __future__ import print_function
import os
import sys

import av


for dir_path, dir_names, file_names in os.walk(sys.argv[1]):
        for name in file_names:
            if name.startswith('.'):
                continue
            path = os.path.join(dir_path, name)
            try:
                fh = av.open(path)
            except (ValueError, av.AVError):
                continue
            try:
                video = fh.streams.video[0]
            except IndexError:
                continue

            print('%9.3f %9.3f (%6.3f) %s' % (1.0 / video.time_base, 1.0 / video.codec_context.time_base, video.codec_context.time_base / video.time_base, path))
