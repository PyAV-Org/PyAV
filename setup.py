import argparse
import os
import pathlib
import platform
import re
import shlex
import subprocess
import sys

if platform.system() == "Darwin":
    major_version = int(platform.mac_ver()[0].split(".")[0])
    if major_version < 12:
        raise OSError("You are using an EOL, unsupported, and out-of-date OS.")


def is_virtualenv():
    return sys.base_prefix != sys.prefix


if not (os.getenv("GITHUB_ACTIONS") == "true" or is_virtualenv()):
    raise ValueError("You are not using a virtual environment")


from Cython.Build import cythonize
from Cython.Compiler.AutoDocTransforms import EmbedSignature
from setuptools import Extension, find_packages, setup

FFMPEG_LIBRARIES = [
    "avformat",
    "avcodec",
    "avdevice",
    "avutil",
    "avfilter",
    "swscale",
    "swresample",
]


# Monkey-patch Cython to not overwrite embedded signatures.
old_embed_signature = EmbedSignature._embed_signature


def insert_enum_in_generated_files(source):
    # Work around Cython failing to add `enum` to `AVChannel` type.
    # TODO: Make Cython bug report
    if source.endswith(".c"):
        with open(source, "r") as file:
            content = file.read()

        # Replace "AVChannel __pyx_v_channel;" with "enum AVChannel __pyx_v_channel;"
        modified_content = re.sub(
            r"\b(?<!enum\s)(AVChannel\s+__pyx_v_\w+;)", r"enum \1", content
        )
        with open(source, "w") as file:
            file.write(modified_content)


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


def get_config_from_directory(ffmpeg_dir):
    """
    Get distutils-compatible extension arguments for a specific directory.
    """
    if not os.path.isdir(ffmpeg_dir):
        print("The specified ffmpeg directory does not exist")
        exit(1)

    include_dir = os.path.join(FFMPEG_DIR, "include")
    library_dir = os.path.join(FFMPEG_DIR, "lib")
    if not os.path.exists(include_dir):
        include_dir = FFMPEG_DIR
    if not os.path.exists(library_dir):
        library_dir = FFMPEG_DIR

    return {
        "include_dirs": [include_dir],
        "libraries": FFMPEG_LIBRARIES,
        "library_dirs": [library_dir],
    }


def get_config_from_pkg_config():
    """
    Get distutils-compatible extension arguments using pkg-config.
    """
    pkg_config = os.environ.get("PKG_CONFIG", "pkg-config")
    try:
        raw_cflags = subprocess.check_output(
            [pkg_config, "--cflags", "--libs"]
            + ["lib" + name for name in FFMPEG_LIBRARIES]
        )
    except FileNotFoundError:
        print(f"{pkg_config} is required for building PyAV")
        exit(1)
    except subprocess.CalledProcessError:
        print(f"{pkg_config} could not find libraries {FFMPEG_LIBRARIES}")
        exit(1)

    known, unknown = parse_cflags(raw_cflags.decode("utf-8"))
    if unknown:
        print("pkg-config returned flags we don't understand: {}".format(unknown))
        if "-pthread" in unknown:
            print("Building PyAV against static FFmpeg libraries is not supported.")
        exit(1)

    return known


def parse_cflags(raw_flags):
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-I", dest="include_dirs", action="append")
    parser.add_argument("-L", dest="library_dirs", action="append")
    parser.add_argument("-l", dest="libraries", action="append")
    parser.add_argument("-D", dest="define_macros", action="append")
    parser.add_argument("-R", dest="runtime_library_dirs", action="append")

    raw_args = shlex.split(raw_flags.strip())
    args, unknown = parser.parse_known_args(raw_args)
    config = {k: v or [] for k, v in args.__dict__.items()}
    for i, x in enumerate(config["define_macros"]):
        parts = x.split("=", 1)
        value = x[1] or None if len(x) == 2 else None
        config["define_macros"][i] = (parts[0], value)
    return config, " ".join(shlex.quote(x) for x in unknown)


# Parse command-line arguments.
FFMPEG_DIR = None
for i, arg in enumerate(sys.argv):
    if arg.startswith("--ffmpeg-dir="):
        FFMPEG_DIR = arg.split("=")[1]
        del sys.argv[i]

# Locate ffmpeg libraries and headers.
if FFMPEG_DIR is not None:
    extension_extra = get_config_from_directory(FFMPEG_DIR)
elif platform.system() != "Windows":
    extension_extra = get_config_from_pkg_config()
else:
    extension_extra = {
        "include_dirs": [],
        "libraries": FFMPEG_LIBRARIES,
        "library_dirs": [],
    }

IMPORT_NAME = "av"

loudnorm_extension = Extension(
    f"{IMPORT_NAME}.filter.loudnorm",
    sources=[
        f"{IMPORT_NAME}/filter/loudnorm.py",
        f"{IMPORT_NAME}/filter/loudnorm_impl.c",
    ],
    include_dirs=[f"{IMPORT_NAME}/filter"] + extension_extra["include_dirs"],
    libraries=extension_extra["libraries"],
    library_dirs=extension_extra["library_dirs"],
)

compiler_directives = {
    "c_string_type": "str",
    "c_string_encoding": "ascii",
    "embedsignature": True,
    "binding": False,
    "language_level": 3,
}

# Add the cythonized loudnorm extension to ext_modules
ext_modules = cythonize(
    loudnorm_extension,
    compiler_directives=compiler_directives,
    build_dir="src",
    include_path=["include"],
)

for dirname, dirnames, filenames in os.walk(IMPORT_NAME):
    for filename in filenames:
        # We are looking for Cython sources.
        if filename.startswith("."):
            continue
        if filename in {"__init__.py", "__main__.py", "about.py", "datasets.py"}:
            continue
        if os.path.splitext(filename)[1] not in {".pyx", ".py"}:
            continue

        pyx_path = os.path.join(dirname, filename)
        base = os.path.splitext(pyx_path)[0]

        # Need to be a little careful because Windows will accept / or \
        # (where os.sep will be \ on Windows).
        mod_name = base.replace("/", ".").replace(os.sep, ".")

        # Cythonize the module.
        ext_modules += cythonize(
            Extension(
                mod_name,
                include_dirs=extension_extra["include_dirs"],
                libraries=extension_extra["libraries"],
                library_dirs=extension_extra["library_dirs"],
                sources=[pyx_path],
            ),
            compiler_directives=compiler_directives,
            build_dir="src",
            include_path=["include"],
        )

for ext in ext_modules:
    for cfile in ext.sources:
        insert_enum_in_generated_files(cfile)


package_folders = pathlib.Path(IMPORT_NAME).glob("**/")
package_data = {
    ".".join(pckg.parts): ["*.pxd", "*.pyi", "*.typed"] for pckg in package_folders
}

setup(
    packages=find_packages(include=[f"{IMPORT_NAME}*"]),
    package_data=package_data,
    ext_modules=ext_modules,
)
