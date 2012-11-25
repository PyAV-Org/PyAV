import sys

from av import open


video = open(sys.argv[1])

video.dump()

