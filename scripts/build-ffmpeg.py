import glob
import os
import platform
import sys

from cibuildpkg import Builder, Package, get_platform, log_group, prepend_env, run

if len(sys.argv) < 2:
    sys.stderr.write("Usage: build-ffmpeg.py <prefix>\n")
    sys.exit(1)

dest_dir = sys.argv[1]
output_dir = os.path.abspath("output")
system = platform.system()
if system == "Linux" and os.environ.get("CIBUILDWHEEL") == "1":
    output_dir = "/output"
output_tarball = os.path.join(output_dir, f"ffmpeg-{get_platform()}.tar.gz")

if not os.path.exists(output_tarball):
    builder = Builder(dest_dir=dest_dir)
    builder.create_directories()

    prepend_env("CPPFLAGS", "-I" + os.path.join(dest_dir, "include"))
    prepend_env("LDFLAGS", "-L" + os.path.join(dest_dir, "lib"))
    prepend_env("PATH", os.path.join(dest_dir, "bin"), separator=":")
    prepend_env(
        "PKG_CONFIG_PATH", os.path.join(dest_dir, "lib", "pkgconfig"), separator=":"
    )

    # install packages
    available_tools = set()
    if system == "Linux" and os.environ.get("CIBUILDWHEEL") == "1":
        with log_group("install packages"):
            run(["yum", "-y", "install", "gperf", "libuuid-devel", "zlib-devel"])
        available_tools.update(["gperf"])

    #### BUILD TOOLS ####

    # install cmake, meson and ninja
    with log_group("install python packages"):
        run(["pip", "install", "cmake", "meson", "ninja"])

    if "gperf" not in available_tools:
        builder.build(
            Package(
                name="gperf",
                source_url="http://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz",
            )
        )

    if "nasm" not in available_tools:
        builder.build(
            Package(
                name="nasm",
                source_url="https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2",
            )
        )

    #### LIBRARIES ###

    builder.build(
        Package(
            name="xz",
            source_url="https://tukaani.org/xz/xz-5.2.5.tar.bz2",
            build_arguments=["--disable-doc", "--disable-nls"],
        )
    )
    builder.build(
        Package(
            name="gmp", source_url="https://gmplib.org/download/gmp/gmp-6.2.0.tar.xz"
        )
    )
    builder.build(
        Package(
            name="png",
            requires=["zlib"],
            source_url="http://deb.debian.org/debian/pool/main/libp/libpng1.6/libpng1.6_1.6.37.orig.tar.gz",
        )
    )
    builder.build(
        Package(
            name="xml2",
            requires=["xz", "zlib"],
            source_url="ftp://xmlsoft.org/libxml2/libxml2-sources-2.9.10.tar.gz",
            build_arguments=["--without-python"],
        )
    )
    builder.build(
        Package(
            name="unistring",
            source_url="https://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.gz",
        )
    )
    builder.build(
        Package(
            name="freetype",
            requires=["png"],
            source_url="https://download.savannah.gnu.org/releases/freetype/freetype-2.10.1.tar.gz",
        )
    )
    builder.build(
        Package(
            name="fontconfig",
            source_url="https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.1.tar.bz2",
            build_arguments=["--disable-nls", "--enable-libxml2"],
        )
    )
    builder.build(
        Package(
            name="fribidi",
            source_url="https://github.com/fribidi/fribidi/releases/download/v1.0.9/fribidi-1.0.9.tar.xz",
        )
    )
    builder.build(
        Package(
            name="nettle",
            requires=["gmp"],
            source_url="https://ftp.gnu.org/gnu/nettle/nettle-3.6.tar.gz",
            build_arguments=["--disable-documentation"],
        )
    )
    builder.build(
        Package(
            name="gnutls",
            requires=["nettle", "unistring", "zlib"],
            source_url="https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.15.tar.xz",
            build_arguments=[
                "--disable-cxx",
                "--disable-doc",
                "--disable-nls",
                "--disable-tests",
                "--disable-tools",
                "--with-included-libtasn1",
                "--without-p11-kit",
            ],
        )
    )

    #### CODECS ###

    builder.build(
        Package(
            name="aom",
            source_url="https://storage.googleapis.com/aom-releases/libaom-3.2.0.tar.gz",
            source_strip_components=0,
            build_system="cmake",
            build_arguments=[
                "-DENABLE_DOCS=0",
                "-DENABLE_EXAMPLES=0",
                "-DENABLE_TESTS=0",
                "-DENABLE_TOOLS=0",
            ],
            build_parallel=False,
        )
    )
    builder.build(
        Package(
            name="ass",
            requires=["freetype", "fribidi"],
            source_url="https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.gz",
        )
    )
    builder.build(
        Package(
            name="bluray",
            requires=["fontconfig"],
            source_url="https://download.videolan.org/pub/videolan/libbluray/1.1.2/libbluray-1.1.2.tar.bz2",
            build_arguments=["--disable-bdjava-jar"],
        )
    )
    builder.build(
        Package(
            name="dav1d",
            requires=["nasm", "ninja"],
            source_url="https://code.videolan.org/videolan/dav1d/-/archive/0.9.2/dav1d-0.9.2.tar.bz2",
            build_system="meson",
        )
    )
    builder.build(
        Package(
            name="lame",
            source_url="http://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz",
        )
    )
    builder.build(
        Package(
            name="ogg",
            source_url="http://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz",
        )
    )
    builder.build(
        Package(
            name="opencore-amr",
            source_url="http://deb.debian.org/debian/pool/main/o/opencore-amr/opencore-amr_0.1.5.orig.tar.gz",
        )
    )
    builder.build(
        Package(
            name="openjpeg",
            source_url="https://github.com/uclouvain/openjpeg/archive/v2.3.1.tar.gz",
            build_system="cmake",
        )
    )
    builder.build(
        Package(
            name="opus",
            source_url="https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz",
            build_arguments=["--disable-extra-programs"],
        )
    )
    builder.build(
        Package(
            name="speex",
            source_url="http://downloads.xiph.org/releases/speex/speex-1.2.0.tar.gz",
            build_arguments=["--disable-binaries"],
        )
    )
    builder.build(
        Package(
            name="twolame",
            source_url="http://deb.debian.org/debian/pool/main/t/twolame/twolame_0.4.0.orig.tar.gz",
        )
    )
    builder.build(
        Package(
            name="vorbis",
            requires=["ogg"],
            source_url="http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.6.tar.gz",
        )
    )
    builder.build(
        Package(
            name="theora",
            requires=["vorbis"],
            source_url="http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.gz",
            build_arguments=["--disable-examples", "--disable-spec"],
        )
    )
    builder.build(
        Package(
            name="wavpack", source_url="http://www.wavpack.com/wavpack-5.3.0.tar.bz2"
        )
    )
    builder.build(
        Package(
            name="x264",
            source_url="https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2",
        )
    )
    builder.build(
        Package(
            name="x265",
            source_url="http://ftp.videolan.org/pub/videolan/x265/x265_3.2.1.tar.gz",
            build_system="cmake",
            source_dir="source",
        )
    )
    builder.build(
        Package(
            name="xvid",
            source_url="https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz",
            source_dir="build/generic",
            build_dir="build/generic",
        )
    )

    #### FFMPEG ###

    builder.build(
        Package(
            name="ffmpeg",
            requires=[
                "aom",
                "ass",
                "bluerary",
                "dav1d",
                "fontconfig",
                "freetype",
                "gmp",
                "gnutls",
                "lame",
                "opencore-amr",
                "openjpeg",
                "speex",
                "theora",
                "twolame",
                "vorbis",
                "wavpack",
                "x264",
                "x265",
                "xml2",
                "xvid",
                "xz",
            ],
            source_url="https://ffmpeg.org/releases/ffmpeg-4.3.2.tar.gz",
            build_arguments=[
                "--disable-doc",
                "--disable-libxcb",
                "--enable-fontconfig",
                "--enable-gmp",
                "--enable-gnutls",
                "--enable-gpl",
                "--enable-libaom",
                "--enable-libass",
                "--enable-libbluray",
                "--enable-libdav1d",
                "--enable-libfreetype",
                "--enable-libmp3lame",
                "--enable-libopencore-amrnb",
                "--enable-libopencore-amrwb",
                "--enable-libopenjpeg",
                "--enable-libopus",
                "--enable-libspeex",
                "--enable-libtheora",
                "--enable-libtwolame",
                "--enable-libvorbis",
                "--enable-libwavpack",
                "--enable-libx264",
                "--enable-libx265",
                "--enable-libxml2",
                "--enable-libxvid",
                "--enable-lzma",
                "--enable-version3",
                "--enable-zlib",
            ],
        )
    )

    if system == "Darwin":
        run(["otool", "-L"] + glob.glob(os.path.join(dest_dir, "lib", "*.dylib")))

    os.makedirs(output_dir, exist_ok=True)
    run(["tar", "czvf", output_tarball, "-C", dest_dir, "include", "lib"])
