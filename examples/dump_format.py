import sys
import logging


logging.basicConfig(level=logging.DEBUG)

import av

fh = av.open(sys.argv[1])
fh.dump_format()
fh.dump_format()
fh.dump_format()

print('here')
