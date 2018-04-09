import av


icontainer = av.open("udp://127.0.0.1:8882")

stream = icontainer.streams.video[0]
print 'stream:', stream.time_base
print 'codecc:', stream.codec_context.time_base
print

for p in icontainer.demux(video=0):
    print p
    print '   ', p.pts, 'in', p.time_base
    for f in p.decode():
        print f
        print '   ', f.pts, 'in', f.time_base
        exit()
        print '   ', f
        print '       ', float(f.pts * p.time_base)




exit()


istreams = [s for s in icontainer.streams if (s.type == 'audio') or (s.type == 'video')]
opts = {
    'x264opts': 'keyint=60:min-keyint=60:no-scenecut',
    'hls_list_size': '60',
    'hls_time': '1',
    'use_localtime': '1',
    'use_localtime_mkdir': '1',
    'hls_segment_filename': 'HR-%Y%m%d%H/%s.ts'
}
ocontainer = av.open("test.m3u8", mode='w', format='hls', options=opts)
ovstream = ocontainer.add_stream("libx264", 1 / ivstream.rate)
oastream = ocontainer.add_stream("aac", 1 / iastream.rate)
ovstream.height = min(720, ivstream.height)
ovstream.width = min(1280, ivstream.width)
ovstream.bit_rate = 3800000  # I normally calculate based on size

for packet in icontainer.demux(istreams):
    for frame in packet.decode():
        if packet.stream.type == 'audio':
            try:
                opacket = oastream.encode(frame)
            except:
                opacket = None
        else:
            try:
                opacket = ovstream.encode(frame)
            except:
                opacket = None
        if opacket is not None:
            try:
                ocontainer.mux(opacket)
            except:
                logger.error('mux failed: ' + str(opacket))
