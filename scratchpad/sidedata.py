import sys

import av



fh = av.open(sys.argv[1])
fh.streams.video[0].flags2 = 'EXPORT_MVS'

for pi, packet in enumerate(fh.demux()):
    #print(pi, packet)
    for fi, frame in enumerate(packet.decode()):
        #print(pi, fi, frame)
        for di, data in enumerate(frame.side_data):
            print(pi, fi, di, data)
