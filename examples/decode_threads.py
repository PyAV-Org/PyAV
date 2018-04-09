import concurrent.futures
import sys

import av


def decode(input_file):

    container = av.open(input_file)

    stream = container.streams.video[0]
    #stream.thread_count = 1

    for _ in container.decode(stream):
        pass

    return input_file


pool = concurrent.futures.ThreadPoolExecutor(4)
for f in pool.map(decode, sys.argv[1:]):
    print(f)



