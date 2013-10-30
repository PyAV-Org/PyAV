import logging
import av.logging as avlog

logging.basicConfig()

print 'current level:', avlog.get_level()

avlog.log(avlog.ERROR, 'example error')

