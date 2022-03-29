import glob
import os
import platform
import shutil
import subprocess
import sys

from cibuildpkg import Builder, Package, get_platform, log_group, run

if len(sys.argv) < 2:
    sys.stderr.write("Usage: build-ffmpeg.py <prefix> [stage]\n")
    sys.stderr.write(
        "       AArch64 build requires stage and possible values can be 1, 2 or 3\n"
    )
    sys.exit(1)

dest_dir = sys.argv[1]
output_dir = os.path.abspath("output")
system = platform.system()
if system == "Linux" and os.environ.get("CIBUILDWHEEL") == "1":
    output_dir = "/output"
output_tarball = os.path.join(output_dir, f"ffmpeg-{get_platform()}.tar.gz")

# FFmpeg has native TLS backends for macOS and Windows
use_gnutls = system == "Linux"

if not os.path.exists(output_tarball):
    builder = Builder(dest_dir=dest_dir)
    builder.create_directories()

    if len(sys.argv) == 3:
        build_stage = int(sys.argv[2]) - 1
    else:
        build_stage = None

    # install packages

    available_tools = set()
    if system == "Linux" and os.environ.get("CIBUILDWHEEL") == "1":
        with log_group("install packages"):
            run(
                [
                    "yum",
                    "-y",
                    "install",
                    "gperf",
                    "libuuid-devel",
                    "libxcb-devel",
                    "zlib-devel",
                ]
            )
        available_tools.update(["gperf"])
    elif system == "Windows":
        available_tools.update(["gperf", "nasm"])

        # print tool locations
        for tool in ["gcc", "g++", "curl", "ld", "nasm", "pkg-config"]:
            run(["where", tool])

    with log_group("install python packages"):
        run(["pip", "install", "cmake", "meson", "ninja"])

    # build tools

    if "gperf" not in available_tools:
        builder.build(
            Package(
                name="gperf",
                source_url="http://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz",
            ),
            for_builder=True,
        )

    if "nasm" not in available_tools:
        builder.build(
            Package(
                name="nasm",
                source_url="https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2",
            ),
            for_builder=True,
        )

    # build packages
    package_groups = [[], [], []]
    package_groups[0] = [
        # libraries
        Package(
            name="xz",
            source_url="https://tukaani.org/xz/xz-5.2.5.tar.bz2",
            build_arguments=[
                "--disable-doc",
                "--disable-lzma-links",
                "--disable-lzmadec",
                "--disable-lzmainfo",
                "--disable-nls",
                "--disable-scripts",
                "--disable-xz",
                "--disable-xzdec",
            ],
        ),
        Package(
            name="gmp",
            source_url="https://gmplib.org/download/gmp/gmp-6.2.1.tar.xz",
            # out-of-tree builds fail on Windows
            build_dir=".",
        ),
        Package(
            name="png",
            source_url="http://deb.debian.org/debian/pool/main/libp/libpng1.6/libpng1.6_1.6.37.orig.tar.gz",
            # avoid an assembler error on Windows
            build_arguments=["PNG_COPTS=-fno-asynchronous-unwind-tables"],
        ),
        Package(
            name="xml2",
            requires=["xz"],
            source_url="https://download.gnome.org/sources/libxml2/2.9/libxml2-2.9.13.tar.xz",
            build_arguments=["--without-python"],
        ),
        Package(
            name="unistring",
            source_url="https://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.gz",
        ),
        Package(
            name="freetype",
            requires=["png"],
            source_url="https://download.savannah.gnu.org/releases/freetype/freetype-2.10.1.tar.gz",
        ),
        Package(
            name="fontconfig",
            requires=["freetype", "xml2"],
            source_url="https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.1.tar.bz2",
            build_arguments=["--disable-nls", "--enable-libxml2"],
        ),
        Package(
            name="fribidi",
            source_url="https://github.com/fribidi/fribidi/releases/download/v1.0.11/fribidi-1.0.11.tar.xz",
        ),
        Package(
            name="harfbuzz",
            requires=["freetype"],
            source_url="https://github.com/harfbuzz/harfbuzz/releases/download/4.1.0/harfbuzz-4.1.0.tar.xz",
            build_arguments=[
                "--with-cairo=no",
                "--with-chafa=no",
                "--with-freetype=yes",
                "--with-glib=no",
            ],
            # parallel build fails on Windows
            build_parallel=platform.system() != "Windows",
        ),
    ]

    if use_gnutls:
        package_groups[0] += [
            Package(
                name="nettle",
                requires=["gmp"],
                source_url="https://ftp.gnu.org/gnu/nettle/nettle-3.7.3.tar.gz",
                build_arguments=["--disable-documentation"],
                # build randomly fails with "*** missing separator.  Stop."
                build_parallel=False,
            ),
            Package(
                name="gnutls",
                requires=["nettle", "unistring"],
                source_url="https://www.gnupg.org/ftp/gcrypt/gnutls/v3.7/gnutls-3.7.3.tar.xz",
                build_arguments=[
                    "--disable-cxx",
                    "--disable-doc",
                    "--disable-guile",
                    "--disable-libdane",
                    "--disable-nls",
                    "--disable-tests",
                    "--disable-tools",
                    "--with-included-libtasn1",
                    "--without-p11-kit",
                ],
            ),
        ]

    package_groups[1] = [
        # codecs
        Package(
            name="aom",
            requires=["cmake"],
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
        ),
        Package(
            name="ass",
            requires=["fontconfig", "freetype", "fribidi", "harfbuzz", "nasm", "png"],
            source_url="https://github.com/libass/libass/releases/download/0.15.2/libass-0.15.2.tar.gz",
        ),
        Package(
            name="bluray",
            requires=["fontconfig"],
            source_url="https://download.videolan.org/pub/videolan/libbluray/1.1.2/libbluray-1.1.2.tar.bz2",
            build_arguments=["--disable-bdjava-jar"],
        ),
        Package(
            name="dav1d",
            requires=["meson", "nasm", "ninja"],
            source_url="https://code.videolan.org/videolan/dav1d/-/archive/0.9.2/dav1d-0.9.2.tar.bz2",
            build_system="meson",
        ),
        Package(
            name="lame",
            source_url="http://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz",
        ),
        Package(
            name="ogg",
            source_url="http://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz",
        ),
        Package(
            name="opencore-amr",
            source_url="http://deb.debian.org/debian/pool/main/o/opencore-amr/opencore-amr_0.1.5.orig.tar.gz",
            # parallel build hangs on Windows
            build_parallel=platform.system() != "Windows",
        ),
        Package(
            name="openjpeg",
            requires=["cmake"],
            source_filename="openjpeg-2.4.0.tar.gz",
            source_url="https://github.com/uclouvain/openjpeg/archive/v2.4.0.tar.gz",
            build_system="cmake",
        ),
        Package(
            name="opus",
            source_url="https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz",
            build_arguments=["--disable-doc", "--disable-extra-programs"],
        ),
        Package(
            name="speex",
            source_url="http://downloads.xiph.org/releases/speex/speex-1.2.0.tar.gz",
            build_arguments=["--disable-binaries"],
        ),
        Package(
            name="twolame",
            source_url="http://deb.debian.org/debian/pool/main/t/twolame/twolame_0.4.0.orig.tar.gz",
            build_arguments=["--disable-sndfile"],
        ),
        Package(
            name="vorbis",
            requires=["ogg"],
            source_url="http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz",
        ),
        Package(
            name="vpx",
            source_filename="vpx-1.11.0.tar.gz",
            source_url="https://github.com/webmproject/libvpx/archive/v1.11.0.tar.gz",
            build_arguments=[
                "--disable-examples",
                "--disable-tools",
                "--disable-unit-tests",
            ],
        ),
        Package(
            name="theora",
            requires=["vorbis"],
            source_url="http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.gz",
            build_arguments=["--disable-examples", "--disable-spec"],
        ),
        Package(
            name="x264",
            source_url="https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2",
        ),
        Package(
            name="x265",
            requires=["cmake"],
            source_url="https://bitbucket.org/multicoreware/x265_git/downloads/x265_3.5.tar.gz",
            build_system="cmake",
            source_dir="source",
        ),
        Package(
            name="xvid",
            requires=["nasm"],
            source_url="https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz",
            source_dir="build/generic",
            build_dir="build/generic",
        ),
    ]
    package_groups[2] = [
        # ffmpeg
        Package(
            name="ffmpeg",
            requires=[
                "aom",
                "ass",
                "bluray",
                "dav1d",
                "fontconfig",
                "freetype",
                "gmp",
                "lame",
                "nasm",
                "opencore-amr",
                "openjpeg",
                "opus",
                "speex",
                "theora",
                "twolame",
                "vorbis",
                "vpx",
                "x264",
                "x265",
                "xml2",
                "xvid",
                "xz",
            ],
            source_url="https://ffmpeg.org/releases/ffmpeg-5.0.1.tar.xz",
            build_arguments=[
                "--disable-alsa",
                "--disable-doc",
                "--disable-mediafoundation",
                "--enable-fontconfig",
                "--enable-gmp",
                "--enable-gnutls" if use_gnutls else "--disable-gnutls",
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
                "--enable-libvpx",
                "--enable-libx264",
                "--enable-libx265",
                "--enable-libxcb"
                if platform.system() == "Linux"
                else "--disable-libxcb",
                "--enable-libxml2",
                "--enable-libxvid",
                "--enable-lzma",
                "--enable-version3",
                "--enable-zlib",
            ],
        ),
    ]

    if build_stage is not None:
        packages = package_groups[build_stage]
    else:
        packages = [p for p_list in package_groups for p in p_list]

    for package in packages:
        builder.build(package)

    if system == "Windows":
        # fix .lib files being installed in the wrong directory
        for name in [
            "avcodec",
            "avdevice",
            "avfilter",
            "avformat",
            "avutil",
            "postproc",
            "swresample",
            "swscale",
        ]:
            shutil.move(
                os.path.join(dest_dir, "bin", name + ".lib"),
                os.path.join(dest_dir, "lib"),
            )

        # copy some libraries provided by mingw
        mingw_bindir = os.path.dirname(
            subprocess.run(["where", "gcc"], check=True, stdout=subprocess.PIPE)
            .stdout.decode()
            .splitlines()[0]
            .strip()
        )
        for name in [
            "libgcc_s_seh-1.dll",
            "libiconv-2.dll",
            "libstdc++-6.dll",
            "libwinpthread-1.dll",
            "zlib1.dll",
        ]:
            shutil.copy(os.path.join(mingw_bindir, name), os.path.join(dest_dir, "bin"))

    # find libraries
    if system == "Darwin":
        libraries = glob.glob(os.path.join(dest_dir, "lib", "*.dylib"))
    elif system == "Linux":
        libraries = glob.glob(os.path.join(dest_dir, "lib", "*.so"))
    elif system == "Windows":
        libraries = glob.glob(os.path.join(dest_dir, "bin", "*.dll"))

    # strip libraries
    if system == "Darwin":
        run(["strip", "-S"] + libraries)
        run(["otool", "-L"] + libraries)
    else:
        run(["strip", "-s"] + libraries)

    # build output tarball
    if build_stage is None or build_stage == 2:
        os.makedirs(output_dir, exist_ok=True)
        run(["tar", "czvf", output_tarball, "-C", dest_dir, "bin", "include", "lib"])
