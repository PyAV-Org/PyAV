
import av
import av.testdata


container = av.open(av.testdata.examples('Toronto,1s.mp4')
for i, frame in enumerate(container.decode(video=0)):
    frame.save('sandbox/{:04d}.jpg'.format(i))

