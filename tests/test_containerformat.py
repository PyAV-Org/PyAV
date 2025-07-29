from av import ContainerFormat, formats_available, open


def test_matroska() -> None:
    with open("test.mkv", "w") as container:
        assert container.default_video_codec != "none"
        assert container.default_audio_codec != "none"
        assert container.default_subtitle_codec == "ass"
        assert "ass" in container.supported_codecs

    fmt = ContainerFormat("matroska")
    assert fmt.is_input and fmt.is_output
    assert fmt.name == "matroska"
    assert fmt.long_name == "Matroska"
    assert "mkv" in fmt.extensions
    assert not fmt.no_file


def test_mov() -> None:
    with open("test.mov", "w") as container:
        assert container.default_video_codec != "none"
        assert container.default_audio_codec != "none"
        assert container.default_subtitle_codec == "none"
        assert "h264" in container.supported_codecs

    fmt = ContainerFormat("mov")
    assert fmt.is_input and fmt.is_output
    assert fmt.name == "mov"
    assert fmt.long_name == "QuickTime / MOV"
    assert "mov" in fmt.extensions
    assert not fmt.no_file


def test_gif() -> None:
    with open("test.gif", "w") as container:
        assert container.default_video_codec == "gif"
        assert container.default_audio_codec == "none"
        assert container.default_subtitle_codec == "none"
        assert "gif" in container.supported_codecs


def test_stream_segment() -> None:
    # This format goes by two names, check both.
    fmt = ContainerFormat("stream_segment")
    assert not fmt.is_input and fmt.is_output
    assert fmt.name == "stream_segment"
    assert fmt.long_name == "streaming segment muxer"
    assert fmt.extensions == set()
    assert fmt.no_file

    fmt = ContainerFormat("ssegment")
    assert not fmt.is_input and fmt.is_output
    assert fmt.name == "ssegment"
    assert fmt.long_name == "streaming segment muxer"
    assert fmt.extensions == set()
    assert fmt.no_file


def test_formats_available() -> None:
    assert formats_available
