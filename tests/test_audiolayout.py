import av
from av import AudioLayout


def _test_stereo(layout: AudioLayout) -> None:
    assert layout.name == "stereo"
    assert layout.nb_channels == 2
    assert repr(layout) == "<av.AudioLayout 'stereo'>"

    # Re-enable when FFmpeg 6.0 is dropped.

    # assert layout.channels[0].name == "FL"
    # assert layout.channels[0].description == "front left"
    # assert repr(layout.channels[0]) == "<av.AudioChannel 'FL' (front left)>"
    # assert layout.channels[1].name == "FR"
    # assert layout.channels[1].description == "front right"
    # assert repr(layout.channels[1]) == "<av.AudioChannel 'FR' (front right)>"


def test_stereo_from_str() -> None:
    layout = AudioLayout("stereo")
    _test_stereo(layout)


def test_stereo_from_layout() -> None:
    layout2 = AudioLayout(AudioLayout("stereo"))
    _test_stereo(layout2)


def test_custom_order_copies() -> None:
    # Custom-order layouts own a heap-allocated channel map; copies must not share it.
    a = AudioLayout("FR+FL")
    b = AudioLayout(a)
    del a
    assert b.name == "2 channels (FR+FL)"
    del b

    frame = av.AudioFrame(format="s16", layout="FR+FL", samples=4)
    layout = frame.layout
    del frame
    assert layout.nb_channels == 2

    ctx = av.CodecContext.create("pcm_s16le", "w")
    assert isinstance(ctx, av.AudioCodecContext)
    ctx.layout = "FR+FL"
    for _ in range(3):
        assert ctx.layout.name == "2 channels (FR+FL)"
