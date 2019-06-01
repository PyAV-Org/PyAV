import concurrent.futures
import sys

import av


def decode(input_file):

    container = av.open(input_file)

    stream = container.streams.video[0]
    stream.thread_type = 3

    for _ in container.decode(stream):
        pass

    return input_file


pool = concurrent.futures.ThreadPoolExecutor(1)
for f in pool.map(decode, sys.argv[1:]):
    print(f)
