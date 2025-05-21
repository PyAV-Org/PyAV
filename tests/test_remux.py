import av
import av.datasets


def test_video_remux() -> None:
    input_path = av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")
    input_ = av.open(input_path)
    output = av.open("remuxed.mkv", "w")

    in_stream = input_.streams.video[0]
    out_stream = output.add_stream_from_template(in_stream)

    for packet in input_.demux(in_stream):
        if packet.dts is None:
            continue

        packet.stream = out_stream
        output.mux(packet)

    input_.close()
    output.close()

    with av.open("remuxed.mkv") as container:
        # Assert output is a valid media file
        assert len(container.streams.video) == 1
        assert len(container.streams.audio) == 0
        assert container.streams.video[0].codec.name == "h264"

        packet_count = 0
        for packet in container.demux(video=0):
            packet_count += 1

        assert packet_count > 50
