import os
import time

import av
import av.datasets
from av.codec.hwaccel import HWAccel, hwdevices_available

# What accelerator to use.
# Recommendations:
#   Windows:
#       - d3d11va (Direct3D 11)
#           * available with built-in ffmpeg in PyAV binary wheels, and gives access to
#             all decoders, but performance may not be as good as vendor native interfaces.
#       - cuda (NVIDIA NVDEC), qsv (Intel QuickSync)
#           * may be faster than d3d11va, but requires custom ffmpeg built with those libraries.
#   Linux (all options require custom FFmpeg):
#       - vaapi (Intel, AMD)
#       - cuda (NVIDIA)
#   Mac:
#       - videotoolbox
#           * available with built-in ffmpeg in PyAV binary wheels, and gives access to
#             all accelerators available on Macs. This is the only option on MacOS.

HW_DEVICE = os.environ["HW_DEVICE"] if "HW_DEVICE" in os.environ else None

if "TEST_FILE_PATH" in os.environ:
    test_file_path = os.environ["TEST_FILE_PATH"]
else:
    test_file_path = av.datasets.curated(
        "pexels/time-lapse-video-of-night-sky-857195.mp4"
    )

if HW_DEVICE is None:
    print(f"Please set HW_DEVICE. Options are: {hwdevices_available()}")
    exit()

assert HW_DEVICE in hwdevices_available(), f"{HW_DEVICE} not available."

print("Decoding in software (auto threading)...")

container = av.open(test_file_path)

container.streams.video[0].thread_type = "AUTO"

start_time = time.time()
frame_count = 0
for packet in container.demux(video=0):
    for _ in packet.decode():
        frame_count += 1

sw_time = time.time() - start_time
sw_fps = frame_count / sw_time
assert frame_count == container.streams.video[0].frames
container.close()

print(
    f"Decoded with software in {sw_time:.2f}s ({sw_fps:.2f} fps).\n"
    f"Decoding with {HW_DEVICE}"
)

hwaccel = HWAccel(device_type=HW_DEVICE, allow_software_fallback=False)

# Note the additional argument here.
container = av.open(test_file_path, hwaccel=hwaccel)

start_time = time.time()
frame_count = 0
for packet in container.demux(video=0):
    for _ in packet.decode():
        frame_count += 1

hw_time = time.time() - start_time
hw_fps = frame_count / hw_time
assert frame_count == container.streams.video[0].frames
container.close()

print(f"Decoded with {HW_DEVICE} in {hw_time:.2f}s ({hw_fps:.2f} fps).")
