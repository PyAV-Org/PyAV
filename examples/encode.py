import av




context = av.open("./sandbox/encode_example.avi", 'w')


stream = context.add_stream("mpeg4")

codec = stream.codec

print "bit_rate", codec.bit_rate
print "time_base", codec.time_base
print "pix_fmt", codec.pix_fmt
print  "size %ix%i" % (codec.width, codec.height)
print "gop_size", codec.gop_size

context.dump()
