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
