from errno import EAGAIN

import cython
from cython.cimports.av.filter.context import FilterContext
from cython.cimports.av.filter.graph import Graph

from av.error import FFmpegError


@cython.cclass
class AudioResampler:
    """AudioResampler(format=None, layout=None, rate=None)

    :param AudioFormat format: The target format, or string that parses to one
        (e.g. ``"s16"``).
    :param AudioLayout layout: The target layout, or an int/string that parses
        to one (e.g. ``"stereo"``).
    :param int rate: The target sample rate.
    """

    def __cinit__(self, format=None, layout=None, rate=None, frame_size=None):
        if format is not None:
            self.format = (
                format if isinstance(format, AudioFormat) else AudioFormat(format)
            )

        if layout is not None:
            self.layout = AudioLayout(layout)

        self.rate = int(rate) if rate else 0
        self.frame_size = int(frame_size) if frame_size else 0
        self.graph = None

    @cython.ccall
    def resample(self, frame: AudioFrame | None) -> list:
        """resample(frame)

        Convert the ``sample_rate``, ``channel_layout`` and/or ``format`` of
        a :class:`~.AudioFrame`.

        :param AudioFrame frame: The frame to convert or `None` to flush.
        :returns: A list of :class:`AudioFrame` in new parameters. If the nothing is to be done return the same frame
            as a single element list.

        """
        # We don't have any input, so don't bother even setting up.
        if not self.graph and frame is None:
            return []

        # Shortcut for passthrough.
        if self.is_passthrough:
            return [frame]

        # Take source settings from the first frame.
        if not self.graph:
            self.template = frame

            # Set some default descriptors.
            self.format = self.format or frame.format
            self.layout = self.layout or frame.layout
            self.rate = self.rate or frame.sample_rate

            # Check if we can passthrough or if there is actually work to do.
            if (
                frame.format.sample_fmt == self.format.sample_fmt
                and frame.layout == self.layout
                and frame.sample_rate == self.rate
                and self.frame_size == 0
            ):
                self.is_passthrough = True
                return [frame]

            # handle resampling with aformat filter
            # (similar to configure_output_audio_filter from ffmpeg)
            self.graph = Graph()
            extra_args = {}
            if frame.time_base is not None:
                extra_args["time_base"] = f"{frame.time_base}"

            abuffer = self.graph.add(
                "abuffer",
                sample_rate=f"{frame.sample_rate}",
                sample_fmt=AudioFormat(frame.format).name,
                channel_layout=frame.layout.name,
                **extra_args,
            )
            aformat = self.graph.add(
                "aformat",
                sample_rates=f"{self.rate}",
                sample_fmts=self.format.name,
                channel_layouts=self.layout.name,
            )
            abuffersink = self.graph.add("abuffersink")
            abuffer.link_to(aformat)
            aformat.link_to(abuffersink)
            self.graph.configure()

            if self.frame_size > 0:
                self.graph.set_audio_frame_size(self.frame_size)

        if frame is not None:
            if (
                frame.format.sample_fmt != self.template.format.sample_fmt
                or frame.layout != self.template.layout
                or frame.sample_rate != self.template.rate
            ):
                raise ValueError("Frame does not match AudioResampler setup.")

        self.graph.push(frame)

        output: list = []
        while True:
            try:
                output.append(self.graph.pull())
            except EOFError:
                break
            except FFmpegError as e:
                if e.errno != EAGAIN:
                    raise
                break

        return output
