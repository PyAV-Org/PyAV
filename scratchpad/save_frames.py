import sys

import av

container = av.open(sys.argv[1])
for i, frame in enumerate(container.decode(video=0)):
    frame.to_image().save('sandbox/%04d.jpg' % i)
    if i > 5:
        break
