from setup_cflags import parse_cflags

BASE_FLAGS = "-I/opt/ffmpeg/include -L/opt/ffmpeg/lib -lavcodec"


def test_parse_cflags_known_flags() -> None:
    config, unknown = parse_cflags(BASE_FLAGS)

    assert unknown == ""
    assert config["include_dirs"] == ["/opt/ffmpeg/include"]
    assert config["library_dirs"] == ["/opt/ffmpeg/lib"]
    assert config["libraries"] == ["avcodec"]
    assert config["runtime_library_dirs"] == []


def test_parse_cflags_dash_r() -> None:
    config, unknown = parse_cflags(f"{BASE_FLAGS} -R/opt/ffmpeg/lib")

    assert unknown == ""
    assert config["runtime_library_dirs"] == ["/opt/ffmpeg/lib"]


def test_parse_cflags_wl_rpath_comma() -> None:
    config, unknown = parse_cflags(f"{BASE_FLAGS} -Wl,-rpath,/opt/ffmpeg/lib")

    assert unknown == ""
    assert config["runtime_library_dirs"] == ["/opt/ffmpeg/lib"]


def test_parse_cflags_wl_rpath_equals() -> None:
    config, unknown = parse_cflags(f"{BASE_FLAGS} -Wl,-rpath=/opt/ffmpeg/lib")

    assert unknown == ""
    assert config["runtime_library_dirs"] == ["/opt/ffmpeg/lib"]


def test_parse_cflags_unknown_flag() -> None:
    config, unknown = parse_cflags(f"{BASE_FLAGS} -Wl,-z,defs")

    assert "-Wl,-z,defs" in unknown
    assert config["runtime_library_dirs"] == []


def test_parse_cflags_ffmpeg_enable_rpath_pkg_config() -> None:
    raw = (
        "-I/opt/ffmpeg/include -L/opt/ffmpeg/lib -lavformat -lavcodec "
        "-lavdevice -lavutil -lavfilter -lswscale -lswresample "
        "-Wl,-rpath,/opt/ffmpeg/lib"
    )
    config, unknown = parse_cflags(raw)

    assert unknown == ""
    assert config["runtime_library_dirs"] == ["/opt/ffmpeg/lib"]
    assert config["include_dirs"] == ["/opt/ffmpeg/include"]
    assert config["library_dirs"] == ["/opt/ffmpeg/lib"]
    assert config["libraries"] == [
        "avformat",
        "avcodec",
        "avdevice",
        "avutil",
        "avfilter",
        "swscale",
        "swresample",
    ]


def test_parse_cflags_deduplicates_rpath() -> None:
    config, unknown = parse_cflags(
        f"{BASE_FLAGS} -R/opt/ffmpeg/lib -Wl,-rpath,/opt/ffmpeg/lib"
    )

    assert unknown == ""
    assert config["runtime_library_dirs"] == ["/opt/ffmpeg/lib"]
