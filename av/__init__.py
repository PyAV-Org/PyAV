# Add the native FFMPEG and MinGW libraries to executable path, so that the
# AV pyd files can find them.
import os
if os.name == 'nt':
    os.environ['PATH'] = os.path.abspath(os.path.dirname(__file__)) + os.pathsep + os.environ['PATH']

# MUST import the core before anything else in order to initalize the underlying
# library that is being wrapped.
from av._core import time_base, pyav_version as __version__

# Capture logging (by importing it).
from av import logging

# For convenience, IMPORT ALL OF THE THINGS (that are constructable by the user).
from av.audio.fifo import AudioFifo
from av.audio.format import AudioFormat
from av.audio.frame import AudioFrame
from av.audio.layout import AudioLayout
from av.audio.resampler import AudioResampler
from av.container import open
from av.utils import AVError
from av.video.format import VideoFormat
from av.video.frame import VideoFrame
