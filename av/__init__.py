
# MUST import the core before anything else in order to initalize the underlying
# library that is being wrapped.
from ._core import time_base

# Capture logging (by importing it).
from . import logging

# For convenience, IMPORT ALL OF THE THINGS (that are constructable by the user).
from .audio.fifo import AudioFifo
from .audio.format import AudioFormat
from .audio.frame import AudioFrame
from .audio.layout import AudioLayout
from .context import Context
from .utils import AVError
from .video.format import VideoFormat
from .video.frame import VideoFrame


def open(*args, **kwargs):
    return Context(*args, **kwargs)
