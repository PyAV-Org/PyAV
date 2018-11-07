
import av
import av.testdata


container = av.open(av.testdata.curated('pexels/time-lapse-video-of-night-sky-857195.mp4'))

for i, frame in enumerate(container.decode(video=0)):
    if i % 30:
        continue

    print(frame)
    frame.to_image().save('sandbox/night-sky.{:04d}.jpg'.format(i))

