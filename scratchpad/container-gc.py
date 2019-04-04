import resource
import gc


import av
import av.datasets

path = av.datasets.curated('pexels/time-lapse-video-of-night-sky-857195.mp4')


def format_bytes(n):
    order = 0
    while n > 1024:
        order += 1
        n //= 1024
    return '%d%sB' % (n, ('', 'k', 'M', 'G', 'T', 'P')[order])

after = resource.getrusage(resource.RUSAGE_SELF)

count = 0

streams = []

while True:

    container = av.open(path)
    # streams.append(container.streams.video[0])

    del container
    gc.collect()
    
    count += 1
    if not count % 100:
        pass
        # streams.clear()
        # gc.collect()

    before = after
    after = resource.getrusage(resource.RUSAGE_SELF)
    print('{:6d} {} ({})'.format(
        count,
        format_bytes(after.ru_maxrss),
        format_bytes(after.ru_maxrss - before.ru_maxrss),
    ))
