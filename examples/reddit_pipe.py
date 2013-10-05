import subprocess
import numpy


proc = subprocess.Popen(['ffmpeg',
    "-i", "sandbox/640x360.mp4",
    "-f", "image2pipe",
    "-pix_fmt", "rgb24",
    "-vcodec", "rawvideo",
    "-"],
    stdout=subprocess.PIPE,
)

while True:
    raw_image = proc.stdout.read(640 * 360 * 3)
    if not raw_image:
        break
    image =  numpy.fromstring(raw_image, dtype='uint8').reshape((640, 360, 3))
