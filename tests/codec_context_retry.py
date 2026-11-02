"""Subprocess regression for codec identity after a real FFmpeg open failure."""

from __future__ import annotations

import io
import sys
from fractions import Fraction

# Exercise the exact compiled package imported by the parent, including in-place builds.
sys.path.insert(0, sys.argv[1])


def main() -> None:
    import av

    buffer = io.BytesIO()
    with av.open(buffer, mode="w", format="adts") as output:
        stream = output.add_stream("aac", rate=48000)
        assert isinstance(stream, av.AudioStream)
        context = stream.codec_context
        assert context is not None
        context.layout = "stereo"
        context.format = "s16"

        for attempt in range(3):
            print(f"invalid-open-{attempt}", flush=True)
            try:
                context.open()
            except av.error.ArgumentError:
                pass
            else:
                raise AssertionError(
                    "AAC must reject the unsupported s16 configuration"
                )
            assert not context.is_open
            assert context.name == "aac"
            assert context.codec.name == "aac"
            assert context.is_encoder and not context.is_decoder
            assert context.supported_options.generic

        # Correcting the configuration must retain the selected implementation
        # and permit real encoding, rather than permanently poisoning the context.
        # FFmpeg also clears ch_layout during failed-open cleanup, so restore
        # the complete valid audio configuration before retrying.
        context.layout = "stereo"
        context.format = "fltp"
        frame = av.AudioFrame(format="s16", layout="stereo", samples=1024)
        frame.sample_rate = 48000
        frame.time_base = Fraction(1, 48000)
        frame.pts = 0
        for plane in frame.planes:
            plane.update(bytes(plane.buffer_size))
        packets = list(stream.encode(frame))
        packets.extend(stream.encode(None))
        assert packets
        for packet in packets:
            output.mux(packet)
    assert buffer.getvalue()
    buffer.seek(0)
    with av.open(buffer, mode="r") as source:
        decoded = list(source.decode(audio=0))
        assert decoded
        assert all(
            frame.sample_rate == 48000 and frame.layout.name == "stereo"
            for frame in decoded
        )
    print("real-codec-retry-and-recovery-pass", flush=True)


if __name__ == "__main__":
    main()
