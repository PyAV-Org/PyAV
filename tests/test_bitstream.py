from __future__ import annotations

import pytest

import av
from av import Packet
from av.bitstream import BitStreamFilterContext, bitstream_filters_available

from .common import TestCase, fate_suite


def is_annexb(packet: Packet | bytes | None) -> bool:
    if packet is None:
        return False

    data = bytes(packet)
    return data[:3] == b"\0\0\x01" or data[:4] == b"\0\0\0\x01"


def test_filters_availible() -> None:
    assert "h264_mp4toannexb" in bitstream_filters_available


def test_filter_chomp() -> None:
    ctx = BitStreamFilterContext("chomp")

    src_packets: tuple[Packet, None] = (Packet(b"\x0012345\0\0\0"), None)
    assert bytes(src_packets[0]) == b"\x0012345\0\0\0"

    result_packets = []
    for p in src_packets:
        result_packets.extend(ctx.filter(p))

    assert len(result_packets) == 1
    assert bytes(result_packets[0]) == b"\x0012345"


def test_filter_setts() -> None:
    ctx = BitStreamFilterContext("setts=pts=N")

    ctx2 = BitStreamFilterContext(b"setts=pts=N")
    del ctx2

    p1 = Packet(b"\0")
    p1.pts = 42
    p2 = Packet(b"\0")
    p2.pts = 50
    src_packets = [p1, p2, None]

    result_packets: list[Packet] = []
    for p in src_packets:
        result_packets.extend(ctx.filter(p))

    assert len(result_packets) == 2
    assert result_packets[0].pts == 0
    assert result_packets[1].pts == 1


def test_filter_h264_mp4toannexb() -> None:
    with av.open(fate_suite("h264/interlaced_crop.mp4"), "r") as container:
        stream = container.streams.video[0]
        ctx = BitStreamFilterContext("h264_mp4toannexb", stream)

        res_packets = []
        for p in container.demux(stream):
            assert not is_annexb(p)
            res_packets.extend(ctx.filter(p))

        assert len(res_packets) == stream.frames

        for p in res_packets:
            assert is_annexb(p)


def test_filter_output_parameters() -> None:
    with av.open(fate_suite("h264/interlaced_crop.mp4"), "r") as container:
        stream = container.streams.video[0]

        assert not is_annexb(stream.codec_context.extradata)
        ctx = BitStreamFilterContext("h264_mp4toannexb", stream)
        assert not is_annexb(stream.codec_context.extradata)
        del ctx

        _ = BitStreamFilterContext("h264_mp4toannexb", stream, out_stream=stream)
        assert is_annexb(stream.codec_context.extradata)


def test_filter_flush() -> None:
    with av.open(fate_suite("h264/interlaced_crop.mp4"), "r") as container:
        stream = container.streams.video[0]
        ctx = BitStreamFilterContext("h264_mp4toannexb", stream)

        res_packets = []
        for p in container.demux(stream):
            res_packets.extend(ctx.filter(p))
        assert len(res_packets) == stream.frames

        container.seek(0)
        # Without flushing, we expect to get an error: "A non-NULL packet sent after an EOF."
        with pytest.raises(ValueError):
            for p in container.demux(stream):
                ctx.filter(p)

        ctx.flush()
        container.seek(0)
        for p in container.demux(stream):
            res_packets.extend(ctx.filter(p))

        assert len(res_packets) == stream.frames * 2
