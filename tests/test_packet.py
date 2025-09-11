from typing import get_args

import av

from .common import fate_suite


class TestProperties:
    def test_is_keyframe(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i in (0, 21, 45, 69, 93, 117):
                    assert packet.is_keyframe
                else:
                    assert not packet.is_keyframe

    def test_is_corrupt(self) -> None:
        with av.open(fate_suite("mov/white_zombie_scrunch-part.mov")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i == 65:
                    assert packet.is_corrupt
                else:
                    assert not packet.is_corrupt

    def test_is_discard(self) -> None:
        with av.open(fate_suite("mov/mov-1elist-ends-last-bframe.mov")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i == 46:
                    assert packet.is_discard
                else:
                    assert not packet.is_discard

    def test_is_disposable(self) -> None:
        with av.open(fate_suite("hap/HAPQA_NoSnappy_127x1.mov")) as container:
            stream = container.streams.video[0]
            for i, packet in enumerate(container.demux(stream)):
                if i == 0:
                    assert packet.is_disposable
                else:
                    assert not packet.is_disposable

    def test_set_duration(self) -> None:
        with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
            for packet in container.demux():
                assert packet.duration is not None
                old_duration = packet.duration
                packet.duration += 10

                assert packet.duration == old_duration + 10


class TestPacketSideData:
    def test_data_types(self) -> None:
        dtypes = get_args(av.packet.PktSideDataT)
        ffmpeg_ver = [int(v) for v in av.ffmpeg_version_info.split(".", 2)[:2]]
        for dtype in dtypes:
            av_enum = av.packet.packet_sidedata_type_from_literal(dtype)
            assert dtype == av.packet.packet_sidedata_type_to_literal(av_enum)

            if (ffmpeg_ver[0] < 8 and dtype == "lcevc") or (
                ffmpeg_ver[0] < 9 and dtype == "rtcp_sr"
            ):
                break

    def test_iter(self) -> None:
        with av.open(fate_suite("h264/extradata-reload-multi-stsd.mov")) as container:
            for pkt in container.demux():
                for sdata in pkt.iter_sidedata():
                    assert pkt.dts == 2 and sdata.data_type == "new_extradata"

    def test_palette(self) -> None:
        with av.open(fate_suite("h264/extradata-reload-multi-stsd.mov")) as container:
            iterpackets = container.demux()
            pkt = next(pkt for pkt in iterpackets if pkt.has_sidedata("new_extradata"))

            sdata = pkt.get_sidedata("new_extradata")
            assert sdata.data_type == "new_extradata"
            assert bool(sdata)
            assert sdata.data_size > 0
            assert sdata.data_desc == "New Extradata"

            nxt = next(iterpackets)  # has no palette

            assert not nxt.has_sidedata("new_extradata")

            sdata1 = nxt.get_sidedata("new_extradata")
            assert sdata1.data_type == "new_extradata"
            assert not bool(sdata1)
            assert sdata1.data_size == 0

            nxt.set_sidedata(sdata, move=True)
            assert not bool(sdata)
