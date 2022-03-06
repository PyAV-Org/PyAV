import argparse
import os
import platform
import re
import shlex
import subprocess
import sys

from Cython.Build import cythonize
from Cython.Compiler.AutoDocTransforms import EmbedSignature
from setuptools import Command, Extension, find_packages, setup
from setuptools.command.build_ext import build_ext


FFMPEG_DIR = None
FFMPEG_LIBRARIES = [
    "avformat",
    "avcodec",
    "avdevice",
    "avutil",
    "avfilter",
    "swscale",
    "swresample",
]

# Read package metadata
about = {}
about_file = os.path.join(os.path.dirname(__file__), "av", "about.py")
with open(about_file, encoding="utf-8") as fp:
    exec(fp.read(), about)


_cflag_parser = argparse.ArgumentParser(add_help=False)
_cflag_parser.add_argument("-I", dest="include_dirs", action="append")
_cflag_parser.add_argument("-L", dest="library_dirs", action="append")
_cflag_parser.add_argument("-l", dest="libraries", action="append")
_cflag_parser.add_argument("-D", dest="define_macros", action="append")
_cflag_parser.add_argument("-R", dest="runtime_library_dirs", action="append")


def parse_cflags(raw_cflags):
    raw_args = shlex.split(raw_cflags.strip())
    args, unknown = _cflag_parser.parse_known_args(raw_args)
    config = {k: v or [] for k, v in args.__dict__.items()}
    for i, x in enumerate(config["define_macros"]):
        parts = x.split("=", 1)
        value = x[1] or None if len(x) == 2 else None
        config["define_macros"][i] = (parts[0], value)
    return config, " ".join(shlex.quote(x) for x in unknown)


def get_library_config(name):
    """Get distutils-compatible extension extras for the given library.

    This requires ``pkg-config``.

    """
    try:
        raw_cflags = subprocess.check_output(["pkg-config", "--cflags", "--libs", name])
    except FileNotFoundError:
        print("pkg-config is required for building PyAV")
        exit(1)
    except subprocess.CalledProcessError:
        print("pkg-config could not find library {}".format(name))
        exit(1)

    known, unknown = parse_cflags(raw_cflags.decode("utf-8"))
    if unknown:
        print("pkg-config returned flags we don't understand: {}".format(unknown))
        exit(1)

    return known


def update_extend(dst, src):
    """Update the `dst` with the `src`, extending values where lists.

    Primiarily useful for integrating results from `get_library_config`.

    """
    for k, v in src.items():
        existing = dst.setdefault(k, [])
        for x in v:
            if x not in existing:
                existing.append(x)


def unique_extend(a, *args):
    a[:] = list(set().union(a, *args))


# Obtain the ffmpeg dir from the "--ffmpeg-dir=<dir>" argument
for i, arg in enumerate(sys.argv):
    if arg.startswith("--ffmpeg-dir="):
        FFMPEG_DIR = arg.split("=")[1]
        break

if FFMPEG_DIR is not None:
    # delete the --ffmpeg-dir arg so that distutils does not see it
    del sys.argv[i]
    if not os.path.isdir(FFMPEG_DIR):
        print("The specified ffmpeg directory does not exist")
        exit(1)
else:
    # Check the environment variable FFMPEG_DIR
    FFMPEG_DIR = os.environ.get("FFMPEG_DIR")
    if FFMPEG_DIR is not None:
        if not os.path.isdir(FFMPEG_DIR):
            FFMPEG_DIR = None

if FFMPEG_DIR is not None:
    ffmpeg_lib = os.path.join(FFMPEG_DIR, "lib")
    ffmpeg_include = os.path.join(FFMPEG_DIR, "include")
    if os.path.exists(ffmpeg_lib):
        ffmpeg_lib = [ffmpeg_lib]
    else:
        ffmpeg_lib = [FFMPEG_DIR]
    if os.path.exists(ffmpeg_include):
        ffmpeg_include = [ffmpeg_include]
    else:
        ffmpeg_include = [FFMPEG_DIR]
else:
    ffmpeg_lib = []
    ffmpeg_include = []


# The "extras" to be supplied to every one of our modules.
# This is expanded heavily by the `config` command.
extension_extra = {
    "include_dirs": ["include"] + ffmpeg_include,  # The first are PyAV's includes.
    "libraries": [],
    "library_dirs": ffmpeg_lib,
}


def dump_config():
    """Print out all the config information we have so far (for debugging)."""
    print("PyAV:", about["__version__"])
    print("Python:", sys.version)
    print("platform:", platform.platform())
    print("extension_extra:")
    for k, vs in extension_extra.items():
        print("\t%s: %s" % (k, vs))


# Monkey-patch Cython to not overwrite embedded signatures.
old_embed_signature = EmbedSignature._embed_signature


def new_embed_signature(self, sig, doc):

    # Strip any `self` parameters from the front.
    sig = re.sub(r"\(self(,\s+)?", "(", sig)

    # If they both start with the same signature; skip it.
    if sig and doc:
        new_name = sig.split("(")[0].strip()
        old_name = doc.split("(")[0].strip()
        if new_name == old_name:
            return doc
        if new_name.endswith("." + old_name):
            return doc

    return old_embed_signature(self, sig, doc)


EmbedSignature._embed_signature = new_embed_signature


# Construct the modules that we find in the "av" directory.
ext_modules = []
for dirname, dirnames, filenames in os.walk("av"):
    for filename in filenames:

        # We are looing for Cython sources.
        if filename.startswith(".") or os.path.splitext(filename)[1] != ".pyx":
            continue

        pyx_path = os.path.join(dirname, filename)
        base = os.path.splitext(pyx_path)[0]

        # Need to be a little careful because Windows will accept / or \
        # (where os.sep will be \ on Windows).
        mod_name = base.replace("/", ".").replace(os.sep, ".")

        ext_modules.append(Extension(mod_name, sources=[pyx_path]))


class ConfigCommand(Command):

    user_options = [
        ("no-pkg-config", None, "do not use pkg-config to configure dependencies"),
        ("verbose", None, "dump out configuration"),
        ("compiler=", "c", "specify the compiler type"),
    ]

    boolean_options = ["no-pkg-config"]

    def initialize_options(self):
        self.compiler = None
        self.no_pkg_config = None

    def finalize_options(self):
        self.set_undefined_options("build", ("compiler", "compiler"))
        self.set_undefined_options("build_ext", ("no_pkg_config", "no_pkg_config"))

    def run(self):

        # For some reason we get the feeling that CFLAGS is not respected, so we parse
        # it here. TODO: Leave any arguments that we can't figure out.
        for name in "CFLAGS", "LDFLAGS":
            known, unknown = parse_cflags(os.environ.pop(name, ""))
            if unknown:
                print(
                    "Warning: We don't understand some of {} (and will leave it in the envvar): {}".format(
                        name, unknown
                    )
                )
                os.environ[name] = unknown
            update_extend(extension_extra, known)

        # Check if we're using pkg-config or not
        if self.no_pkg_config:
            # Simply assume we have everything we need!
            update_extend(extension_extra, {"libraries": FFMPEG_LIBRARIES})
        else:
            # Get the config for the libraries that we require.
            for name in FFMPEG_LIBRARIES:
                update_extend(extension_extra, get_library_config("lib" + name))

        if self.verbose:
            dump_config()

        # Apply configuration to all modules.
        for ext in self.distribution.ext_modules:
            for key, value in extension_extra.items():
                setattr(ext, key, value)


class CythonizeCommand(Command):

    user_options = []

    def initialize_options(self):
        pass

    def finalize_options(self):
        pass

    def run(self):

        # Cythonize, if required. We do it individually since we must update
        # the existing extension instead of replacing them all.
        for i, ext in enumerate(self.distribution.ext_modules):
            if any(s.endswith(".pyx") for s in ext.sources):
                new_ext = cythonize(
                    ext,
                    compiler_directives=dict(
                        c_string_type="str",
                        c_string_encoding="ascii",
                        embedsignature=True,
                        language_level=2,
                    ),
                    build_dir="src",
                    include_path=ext.include_dirs,
                )[0]
                ext.sources = new_ext.sources


class BuildExtCommand(build_ext):

    if os.name != "nt":
        user_options = build_ext.user_options + [
            ("no-pkg-config", None, "do not use pkg-config to configure dependencies")
        ]

        boolean_options = build_ext.boolean_options + ["no-pkg-config"]

        def initialize_options(self):
            build_ext.initialize_options(self)
            self.no_pkg_config = None

    else:
        no_pkg_config = 1

    def run(self):

        # Propagate build options to config
        obj = self.distribution.get_command_obj("config")
        obj.compiler = self.compiler
        obj.no_pkg_config = self.no_pkg_config
        obj.include_dirs = self.include_dirs
        obj.libraries = self.libraries
        obj.library_dirs = self.library_dirs

        self.run_command("config")

        # Propagate config to cythonize.
        for i, ext in enumerate(self.distribution.ext_modules):
            unique_extend(ext.include_dirs, self.include_dirs)
            unique_extend(ext.library_dirs, self.library_dirs)
            unique_extend(ext.libraries, self.libraries)

        self.run_command("cythonize")
        build_ext.run(self)


setup(
    name="av",
    version=about["__version__"],
    description="Pythonic bindings for FFmpeg's libraries.",
    author="Mike Boers",
    author_email="pyav@mikeboers.com",
    url="https://github.com/PyAV-Org/PyAV",
    packages=find_packages(exclude=["build*", "examples*", "scratchpad*", "tests*"]),
    zip_safe=False,
    ext_modules=ext_modules,
    cmdclass={
        "build_ext": BuildExtCommand,
        "config": ConfigCommand,
        "cythonize": CythonizeCommand,
    },
    test_suite="tests",
    entry_points={
        "console_scripts": [
            "pyav = av.__main__:main",
        ],
    },
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: BSD License",
        "Natural Language :: English",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: POSIX",
        "Operating System :: Unix",
        "Operating System :: Microsoft :: Windows",
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3.6",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Topic :: Software Development :: Libraries :: Python Modules",
        "Topic :: Multimedia :: Sound/Audio",
        "Topic :: Multimedia :: Sound/Audio :: Conversion",
        "Topic :: Multimedia :: Video",
        "Topic :: Multimedia :: Video :: Conversion",
    ],
)
