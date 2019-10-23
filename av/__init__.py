# Add the native FFMPEG and MinGW libraries to executable path, so that the
# AV pyd files can find them.
import os
if os.name == 'nt':
    os.environ['PATH'] = os.path.abspath(os.path.dirname(__file__)) + os.pathsep + os.environ['PATH']

# MUST import the core before anything else in order to initalize the underlying
# library that is being wrapped.
from av._core import time_base, pyav_version as __version__, library_versions

# Capture logging (by importing it).
from av import logging

# For convenience, IMPORT ALL OF THE THINGS (that are constructable by the user).
from av.audio.fifo import AudioFifo
from av.audio.format import AudioFormat
from av.audio.frame import AudioFrame
from av.audio.layout import AudioLayout
from av.audio.resampler import AudioResampler
from av.codec.codec import Codec, codecs_available
from av.codec.context import CodecContext
from av.container import open
from av.format import ContainerFormat, formats_available
from av.packet import Packet
from av.error import *  # noqa: F403; This is limited to exception types.
from av.video.format import VideoFormat
from av.video.frame import VideoFrame

# Backwards compatibility
AVError = FFmpegError  # noqa: F405
