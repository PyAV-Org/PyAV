# Add the native FFMPEG and MinGW libraries to executable path, so that the
# AV pyd files can find them.
import os
if os.name == 'nt':
    os.environ['PATH'] = os.path.abspath(os.path.dirname(__file__)) + os.pathsep + os.environ['PATH']

# MUST import the core before anything else in order to initalize the underlying
# library that is being wrapped.
from ._core import time_base, pyav_version as __version__

# Capture logging (by importing it).
from . import logging

# For convenience, IMPORT ALL OF THE THINGS (that are constructable by the user).
from .audio.fifo import AudioFifo
from .audio.format import AudioFormat
from .audio.frame import AudioFrame
from .audio.layout import AudioLayout
from .audio.resampler import AudioResampler
from .container import open
from .utils import AVError
from .video.format import VideoFormat
from .video.frame import VideoFrame
