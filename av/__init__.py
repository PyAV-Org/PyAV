import os
import sys

# Some Python versions distributed by Conda have a buggy `os.add_dll_directory`
# which prevents binary wheels from finding the FFmpeg DLLs in the `av.libs`
# directory. We work around this by adding `av.libs` to the PATH.
if (
    os.name == "nt"
    and sys.version_info[:2] in ((3, 8), (3, 9))
    and os.path.exists(os.path.join(sys.base_prefix, "conda-meta"))
):
    os.environ["PATH"] = (
        os.path.abspath(os.path.join(os.path.dirname(__file__), os.pardir, "av.libs"))
        + os.pathsep
        + os.environ["PATH"]
    )

# MUST import the core before anything else in order to initialize the underlying
# library that is being wrapped.
from av._core import time_base, library_versions

# Capture logging (by importing it).
from av import logging

# For convenience, import all common attributes.
from av.about import __version__
from av.audio.codeccontext import AudioCodecContext
from av.audio.fifo import AudioFifo
from av.audio.format import AudioFormat
from av.audio.frame import AudioFrame
from av.audio.layout import AudioLayout
from av.audio.resampler import AudioResampler
from av.audio.stream import AudioStream
from av.bitstream import BitStreamFilterContext, bitstream_filters_available
from av.codec.codec import Codec, codecs_available
from av.codec.context import CodecContext
from av.container import open
from av.format import ContainerFormat, formats_available
from av.packet import Packet
from av.error import *  # noqa: F403; This is limited to exception types.
from av.video.codeccontext import VideoCodecContext
from av.video.format import VideoFormat
from av.video.frame import VideoFrame
from av.video.stream import VideoStream

# Backwards compatibility
AVError = FFmpegError  # noqa: F405

__all__ = (
    "__version__",
    "time_base",
    "library_versions",
    "AudioCodecContext",
    "AudioFifo",
    "AudioFormat",
    "AudioFrame",
    "AudioLayout",
    "AudioResampler",
    "AudioStream",
    "BitStreamFilterContext",
    "bitstream_filters_available",
    "Codec",
    "codecs_available",
    "CodecContext",
    "open",
    "ContainerFormat",
    "formats_available",
    "Packet",
    "VideoCodecContext",
    "VideoFormat",
    "VideoFrame",
    "VideoStream",
)


def get_include() -> str:
    """
    Returns the path to the `include` folder to be used when building extensions to av.
    """
    # Installed package
    include_path = os.path.join(os.path.dirname(__file__), "include")
    if os.path.exists(include_path):
        return include_path
    # Running from source directory
    return os.path.join(os.path.dirname(__file__), os.pardir, "include")
