import sys

import av


fh = av.open(sys.argv[1])
fh.streams.video[0].export_mvs = True
# fh.streams.video[0].flags2 |= 'EXPORT_MVS'

for pi, packet in enumerate(fh.demux()):
    for fi, frame in enumerate(packet.decode()):

        for di, data in enumerate(frame.side_data):

            print(pi, fi, di, data)

            print(data.to_ndarray())

            for mi, vec in enumerate(data):

                print(mi, vec)

                if mi > 10:
                    exit()

