import os
import sys

import cv2
from av import open


video = open(sys.argv[1])

stream = next(s for s in video.streams if s.type == 'video')

for packet in video.demux(stream):
    for frame in packet.decode():
    	# some other formats gray16be, bgr24, rgb24
        img = frame.to_nd_array(format='bgr24')
        cv2.imshow("Test", img)

    if cv2.waitKey(1) == 27:
    	break
	cv2.destroyAllWindows()

