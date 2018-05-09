import sys
import logging

logging.basicConfig(level=logging.DEBUG)
logging.getLogger('libav').setLevel(logging.DEBUG)

import av

fh = av.open(sys.argv[1])
print(fh.dumps_format())
