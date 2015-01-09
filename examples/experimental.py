import argparse

import av


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument('output')
args = arg_parser.parse_args()

of = av.open(args.output, 'w')
print of

for codec_name in 'aac', 'vorbis':
    try:
        os = of.add_stream(codec_name)
    except Exception as e:
        print e
    else:
        print os
