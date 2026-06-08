from fractions import Fraction

import pytest

import av
from av import AudioFrame, AudioResampler


def test_flush_immediately() -> None:
    """
    If we flush the resampler before passing any input, it returns
    a `None` frame without setting up the graph.
    """

    resampler = AudioResampler()

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 0


def test_identity_passthrough() -> None:
    """
    If we don't ask it to do anything, it won't.
    """

    resampler = AudioResampler()

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1
    assert iframe is oframes[0]

    # resample another frame
    iframe.pts = 1024

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1
    assert iframe is oframes[0]

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 0


def test_matching_passthrough() -> None:
    """
    If the frames match, it won't do anything.
    """

    resampler = AudioResampler("s16", "stereo")

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1
    assert iframe is oframes[0]

    # resample another frame
    iframe.pts = 1024

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1
    assert iframe is oframes[0]

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 0


def test_pts_assertion_same_rate() -> None:
    av.logging.set_level(av.logging.VERBOSE)
    resampler = AudioResampler("s16", "mono")

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    iframe.time_base = Fraction(1, 48000)
    iframe.pts = 0

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 0
    assert oframe.time_base == iframe.time_base
    assert oframe.sample_rate == iframe.sample_rate
    assert oframe.samples == iframe.samples

    # resample another frame
    iframe.pts = 1024

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 1024
    assert oframe.time_base == iframe.time_base
    assert oframe.sample_rate == iframe.sample_rate
    assert oframe.samples == iframe.samples

    # resample another frame with a pts gap, do not raise exception
    iframe.pts = 9999
    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 9999
    assert oframe.time_base == iframe.time_base
    assert oframe.sample_rate == iframe.sample_rate
    assert oframe.samples == iframe.samples

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 0
    av.logging.set_level(None)


def test_pts_assertion_new_rate_up() -> None:
    resampler = AudioResampler("s16", "mono", 44100)

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    iframe.time_base = Fraction(1, 48000)
    iframe.pts = 0

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 0
    assert oframe.time_base == Fraction(1, 44100)
    assert oframe.sample_rate == 44100
    assert oframe.samples == 925

    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    iframe.time_base = Fraction(1, 48000)
    iframe.pts = 1024

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 925
    assert oframe.time_base == Fraction(1, 44100)
    assert oframe.sample_rate == 44100
    assert oframe.samples == 941

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 941 + 925
    assert oframe.time_base == Fraction(1, 44100)
    assert oframe.sample_rate == 44100
    assert oframe.samples == 15


def test_pts_assertion_new_rate_down() -> None:
    resampler = AudioResampler("s16", "mono", 48000)

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 44100
    iframe.time_base = Fraction(1, 44100)
    iframe.pts = 0

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 0
    assert oframe.time_base == Fraction(1, 48000)
    assert oframe.sample_rate == 48000
    assert oframe.samples == 1098

    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 44100
    iframe.time_base = Fraction(1, 44100)
    iframe.pts = 1024

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 1098
    assert oframe.time_base == Fraction(1, 48000)
    assert oframe.sample_rate == 48000
    assert oframe.samples == 1114

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 1114 + 1098
    assert oframe.time_base == Fraction(1, 48000)
    assert oframe.sample_rate == 48000
    assert oframe.samples == 18


def test_pts_assertion_new_rate_fltp() -> None:
    resampler = AudioResampler("fltp", "mono", 8000, 1024)

    # resample one frame
    iframe = AudioFrame("s16", "mono", 1024)
    iframe.sample_rate = 8000
    iframe.time_base = Fraction(1, 1000)
    iframe.pts = 0

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 0
    assert oframe.time_base == Fraction(1, 8000)
    assert oframe.sample_rate == 8000
    assert oframe.samples == 1024

    iframe = AudioFrame("s16", "mono", 1024)
    iframe.sample_rate = 8000
    iframe.time_base = Fraction(1, 1000)
    iframe.pts = 8192

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 65536
    assert oframe.time_base == Fraction(1, 8000)
    assert oframe.sample_rate == 8000
    assert oframe.samples == 1024

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 0


def test_pts_missing_time_base() -> None:
    resampler = AudioResampler("s16", "mono", 44100)

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    iframe.pts = 0

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 0
    assert oframe.time_base == Fraction(1, 44100)
    assert oframe.sample_rate == 44100

    # flush
    oframes = resampler.resample(None)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.pts == 925
    assert oframe.time_base == Fraction(1, 44100)
    assert oframe.sample_rate == 44100
    assert oframe.samples == 16


def test_swr_options() -> None:
    """
    libswresample options are passed through to the underlying aresample filter.
    """
    resampler = AudioResampler(
        "fltp",
        "mono",
        16000,
        options={"filter_size": "32", "phase_shift": "12", "cutoff": "0.95"},
    )
    assert resampler.options == {
        "filter_size": "32",
        "phase_shift": "12",
        "cutoff": "0.95",
    }

    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    iframe.time_base = Fraction(1, 48000)
    iframe.pts = 0

    oframes = resampler.resample(iframe)
    assert len(oframes) == 1

    oframe = oframes[0]
    assert oframe.sample_rate == 16000
    assert oframe.format.name == "fltp"
    assert oframe.layout.name == "mono"


def test_swr_options_invalid() -> None:
    """
    An unknown option is reported rather than silently ignored.
    """
    resampler = AudioResampler("s16", "mono", 44100, options={"not_a_real_option": "1"})

    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    iframe.time_base = Fraction(1, 48000)
    iframe.pts = 0

    with pytest.raises(ValueError, match="unused config: not_a_real_option"):
        resampler.resample(iframe)


def test_mismatched_input() -> None:
    """
    Consecutive frames must have the same layout, sample format and sample rate.
    """
    resampler = AudioResampler("s16", "mono", 44100)

    # resample one frame
    iframe = AudioFrame("s16", "stereo", 1024)
    iframe.sample_rate = 48000
    resampler.resample(iframe)

    # resample another frame with a sample format
    iframe = AudioFrame("s16", "mono", 1024)
    iframe.sample_rate = 48000
    with pytest.raises(
        ValueError, match="Frame does not match AudioResampler setup."
    ) as cm:
        resampler.resample(iframe)
