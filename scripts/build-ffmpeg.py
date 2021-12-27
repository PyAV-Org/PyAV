import glob
import os
import platform
import shutil
import subprocess
import sys

if len(sys.argv) < 2:
    sys.stderr.write("Usage: build-ffmpeg.py <prefix>\n")
    sys.exit(1)

ffmpeg_version = "4.3.2"

dest_dir = sys.argv[1]
build_dir = os.path.abspath("build")
patch_dir = os.path.abspath("patches")
source_dir = os.path.abspath("source")

for d in [build_dir, dest_dir]:
    if os.path.exists(d):
        shutil.rmtree(d)


def build(package, configure_args=[]):
    path = os.path.join(build_dir, package)
    os.chdir(path)
    run(["./configure"] + configure_args + ["--prefix=" + dest_dir])
    run(["make", "-j"])
    run(["make", "install"])
    os.chdir(build_dir)


def prepend_env(name, new, separator=" "):
    old = os.environ.get(name)
    if old:
        os.environ[name] = new + separator + old
    else:
        os.environ[name] = new


def extract(package, url, *, strip_components=1):
    path = os.path.join(build_dir, package)
    patch = os.path.join(patch_dir, package + ".patch")
    tarball = os.path.join(source_dir, url.split("/")[-1])

    # download tarball
    if not os.path.exists(tarball):
        run(["curl", "-L", "-o", tarball, url])

    # extract tarball
    os.mkdir(path)
    run(["tar", "xf", tarball, "-C", path, "--strip-components", str(strip_components)])

    # apply patch
    if os.path.exists(patch):
        run(["patch", "-d", path, "-i", patch, "-p1"])


def run(cmd):
    sys.stdout.write("- Running: %s\n" % cmd)
    subprocess.run(cmd, check=True, stderr=sys.stderr.buffer, stdout=sys.stdout.buffer)


cmake_args = ["-DCMAKE_INSTALL_LIBDIR=lib", "-DCMAKE_INSTALL_PREFIX=" + dest_dir]
machine = platform.machine()
system = platform.system()
if system == "Linux":
    output_dir = "/output"
    output_tarball = os.path.join(output_dir, f"ffmpeg-manylinux_{machine}.tar.gz")
elif system == "Darwin":
    output_dir = os.path.abspath("output")
    output_tarball = os.path.join(output_dir, f"ffmpeg-macosx_{machine}.tar.gz")
    cmake_args.append("-DCMAKE_INSTALL_NAME_DIR=" + os.path.join(dest_dir, "lib"))
else:
    raise Exception("Unsupported system: %s" % system)

for d in [build_dir, output_dir, source_dir]:
    if not os.path.exists(d):
        os.mkdir(d)
if not os.path.exists(output_tarball):
    os.chdir(build_dir)

    prepend_env("CPPFLAGS", "-I" + os.path.join(dest_dir, "include"))
    prepend_env("LDFLAGS", "-L" + os.path.join(dest_dir, "lib"))
    prepend_env("PATH", os.path.join(dest_dir, "bin"), separator=":")
    prepend_env(
        "PKG_CONFIG_PATH", os.path.join(dest_dir, "lib", "pkgconfig"), separator=":"
    )

    # install packages
    if system == "Linux" and os.environ.get("CIBUILDWHEEL") == "1":
        run(["yum", "-y", "install", "libuuid-devel", "zlib-devel"])

    #### BUILD TOOLS ####

    # install cmake, meson and ninja
    run(["pip", "install", "cmake", "meson", "ninja"])

    # install gperf
    extract("gperf", "http://ftp.gnu.org/pub/gnu/gperf/gperf-3.1.tar.gz")
    build("gperf")

    # install nasm
    extract(
        "nasm",
        "https://www.nasm.us/pub/nasm/releasebuilds/2.14.02/nasm-2.14.02.tar.bz2",
    )
    build("nasm")

    #### LIBRARIES ###

    # build xz
    extract("xz", "https://tukaani.org/xz/xz-5.2.5.tar.bz2")
    build("xz")

    # build gmp
    extract("gmp", "https://gmplib.org/download/gmp/gmp-6.2.0.tar.xz")
    build("gmp")

    # build png (requires zlib)
    extract(
        "png",
        "http://deb.debian.org/debian/pool/main/libp/libpng1.6/libpng1.6_1.6.37.orig.tar.gz",
    )
    build("png")

    # build xml2 (requires xz and zlib)
    extract("xml2", "ftp://xmlsoft.org/libxml2/libxml2-sources-2.9.10.tar.gz")
    build("xml2", ["--without-python"])

    # build unistring
    extract(
        "unistring", "https://ftp.gnu.org/gnu/libunistring/libunistring-0.9.10.tar.gz"
    )
    build("unistring")

    # build gettext (requires unistring and xml2)
    extract("gettext", "https://ftp.gnu.org/pub/gnu/gettext/gettext-0.20.2.tar.gz")
    build("gettext", ["--disable-java"])

    # build freetype (requires png)
    extract(
        "freetype",
        "https://download.savannah.gnu.org/releases/freetype/freetype-2.10.1.tar.gz",
    )
    build("freetype")

    # build fontconfig (requires freetype, libxml2 and uuid)
    extract(
        "fontconfig",
        "https://www.freedesktop.org/software/fontconfig/release/fontconfig-2.13.1.tar.bz2",
    )
    build("fontconfig", ["--enable-libxml2"])

    # build fribidi
    extract(
        "fribidi",
        "https://github.com/fribidi/fribidi/releases/download/v1.0.9/fribidi-1.0.9.tar.xz",
    )
    build("fribidi")

    # build nettle (requires gmp)
    extract("nettle", "https://ftp.gnu.org/gnu/nettle/nettle-3.6.tar.gz")
    build("nettle", ["--libdir=" + os.path.join(dest_dir, "lib")])

    # build gnutls (requires nettle and unistring)
    extract(
        "gnutls", "https://www.gnupg.org/ftp/gcrypt/gnutls/v3.6/gnutls-3.6.15.tar.xz"
    )
    build(
        "gnutls",
        [
            "--disable-doc",
            "--disable-tools",
            "--with-included-libtasn1",
            "--without-p11-kit",
        ],
    )

    #### CODECS ###

    # build aom
    extract(
        "aom",
        "https://aomedia.googlesource.com/aom/+archive/a6091ebb8a7da245373e56a005f2bb95be064e03.tar.gz",
        strip_components=0,
    )
    os.mkdir(os.path.join("aom", "tmp"))
    os.chdir(os.path.join("aom", "tmp"))
    run(["cmake", ".."] + cmake_args + ["-DBUILD_SHARED_LIBS=1"])
    run(["make"])
    run(["make", "install"])
    os.chdir(build_dir)

    # build ass (requires freetype and fribidi)
    extract(
        "ass",
        "https://github.com/libass/libass/releases/download/0.14.0/libass-0.14.0.tar.gz",
    )
    build("ass")

    # build bluray (requires fontconfig)
    extract(
        "bluray",
        "https://download.videolan.org/pub/videolan/libbluray/1.1.2/libbluray-1.1.2.tar.bz2",
    )
    build("bluray", ["--disable-bdjava-jar"])

    # build dav1d (requires meson, nasm and ninja)
    extract(
        "dav1d",
        "https://code.videolan.org/videolan/dav1d/-/archive/0.9.2/dav1d-0.9.2.tar.bz2",
    )
    os.mkdir(os.path.join("dav1d", "build"))
    os.chdir(os.path.join("dav1d", "build"))
    run(["meson", "..", "--libdir=lib", "--prefix=" + dest_dir])
    run(["ninja"])
    run(["ninja", "install"])
    os.chdir(build_dir)

    # build lame
    extract(
        "lame", "http://deb.debian.org/debian/pool/main/l/lame/lame_3.100.orig.tar.gz"
    )
    run(["sed", "-i.bak", "/^lame_init_old$/d", "lame/include/libmp3lame.sym"])
    build("lame")

    # build ogg
    extract("ogg", "http://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz")
    build("ogg")

    # build opencore-amr
    extract(
        "opencore-amr",
        "http://deb.debian.org/debian/pool/main/o/opencore-amr/opencore-amr_0.1.5.orig.tar.gz",
    )
    build("opencore-amr")

    # build openjpeg
    extract("openjpeg", "https://github.com/uclouvain/openjpeg/archive/v2.3.1.tar.gz")
    os.chdir("openjpeg")
    run(["cmake", "."] + cmake_args)
    run(["make", "-j"])
    run(["make", "install"])
    os.chdir(build_dir)

    # build opus
    extract("opus", "https://archive.mozilla.org/pub/opus/opus-1.3.1.tar.gz")
    build("opus")

    # build speex
    extract("speex", "http://downloads.xiph.org/releases/speex/speex-1.2.0.tar.gz")
    build("speex")

    # build twolame
    extract(
        "twolame",
        "http://deb.debian.org/debian/pool/main/t/twolame/twolame_0.4.0.orig.tar.gz",
    )
    build("twolame")

    # build vorbis (requires ogg)
    extract(
        "vorbis", "http://downloads.xiph.org/releases/vorbis/libvorbis-1.3.6.tar.gz"
    )
    build("vorbis")

    # build theora (requires vorbis)
    extract(
        "theora", "http://downloads.xiph.org/releases/theora/libtheora-1.1.1.tar.gz"
    )
    build("theora", ["--disable-examples", "--disable-spec"])

    # build wavpack
    extract("wavpack", "http://www.wavpack.com/wavpack-5.3.0.tar.bz2")
    build("wavpack")

    # build x264
    extract(
        "x264",
        "https://code.videolan.org/videolan/x264/-/archive/master/x264-master.tar.bz2",
    )
    build("x264", ["--enable-shared"])

    # build x265
    extract("x265", "http://ftp.videolan.org/pub/videolan/x265/x265_3.2.1.tar.gz")
    os.chdir("x265/build")
    run(["cmake", "../source"] + cmake_args)
    run(["make", "-j"])
    run(["make", "install"])
    os.chdir(build_dir)

    # build xvid
    extract("xvid", "https://downloads.xvid.com/downloads/xvidcore-1.3.7.tar.gz")
    build("xvid/build/generic")

    # build ffmpeg
    extract("ffmpeg", f"https://ffmpeg.org/releases/ffmpeg-{ffmpeg_version}.tar.gz")
    build(
        "ffmpeg",
        [
            "--disable-doc",
            "--disable-libxcb",
            "--disable-static",
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
            "--enable-shared",
            "--enable-version3",
            "--enable-zlib",
        ],
    )

    if system == "Darwin":
        run(["otool", "-L"] + glob.glob(os.path.join(dest_dir, "lib", "*.dylib")))

    run(["tar", "czvf", output_tarball, "-C", dest_dir, "include", "lib"])
