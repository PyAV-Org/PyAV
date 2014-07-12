import os
import platform
from collections import defaultdict
from Cython.Distutils import build_ext
from setuptools import setup, Extension, find_packages, dist
# Below, pkgconfig (Python bindings to pkg-config) will be installed
# and imported if the platform is not Windows.


version = '0.1.0'

required_libs = ['libavformat', 'libavcodec', 'libavutil', 'libswscale']
pick_one_libs = ['libswresample', 'libavresample']

# Explicitly specify each and every .pyx file. And, below, generate
# extensions for each list separately. This is a little extra work
# but it helps when debugging difficult builds.
av_files = ['_core', 'container', 'format', 'frame', 'logging', 'packet',
            'plane', 'stream', 'utils']
av_video_files = ['format', 'frame', 'plane', 'stream', 'swscontext']
av_audio_files = ['fifo', 'format', 'frame', 'layout', 'plane', 'resampler',
                  'stream']
av_subtitles_files = ['stream', 'subtitle']


class LibraryNotFoundError(Exception):
    pass


def check_for_libraries():
    "Raise if the necessary libraries are not found."
    missing = []
    for lib in required_libs:
        if not pkgconfig.exists(lib):
            missing.append(lib)
            continue
    if missing:
        raise LibraryNotFoundError(
            "Could not find the required libraries: {0}".format(
                ' '.join(missing)))

    missing = []
    for lib in pick_one_libs:
        if not pkgconfig.exists(lib):
            missing.append(lib)
    if len(missing) > 1:
        raise LibraryNotFoundError(
            "Could not find either of these libraries: {0}."
            "One or the other is required.".format(' '.join(missing)))


def make_extension_name(basename, path):
    """Utitily: 'format', 'av/video' -> 'av.video.format'"""
    split_path = list(os.path.split(path)) + [basename]
    try:
	split_path.remove('')  # fix corner case: os.split.path('av') -> ('', 'av')
    except ValueError:
	pass
    return '.'.join(split_path)
    

def generate_extensions(basenames, path, extra_args):
    """Generate extension from a list of .pyx filenames.

    The list of names passed should not include the .pyx."""

    extensions = \
        [Extension(make_extension_name(basename, path),
                   language='c',
                   sources=[os.path.join(path, '{0}.pyx'.format(basename))],
                   depends=[os.path.join(path, '{0}.pxd'.format(basename))],
                   include_dirs = (extra_args['include_dirs'] +
                                   [path, '.', 'include']),
                   library_dirs = extra_args['library_dirs'],
                   libraries = extra_args['libraries'],
                   define_macros = extra_args['define_macros'])
        for basename in basenames]
    return extensions


windows = platform.system() == 'Windows'
if not windows:
    dist.Distribution(dict(setup_requires='pkgconfig'))
    # installs pkgconfig (a Python interface to pkg-config) immediately
    import pkgconfig


    check_for_libraries()  # raises to stop build if any required lib not found

    # Get info from pkgconfig. It returns a defaultdict of sets.
    extra_args = pkgconfig.parse(' '.join(required_libs + pick_one_libs))
    extra_args = {k: list(v) for k, v in extra_args.items()}  # dict of lists

# Again, generating separately to ease debugging.
av_extensions = generate_extensions(av_files, 'av',
                                    extra_args)
av_video_extensions = generate_extensions(av_video_files, 'av/video',
                                          extra_args)
av_audio_extensions = generate_extensions(av_audio_files, 'av/audio',
                                          extra_args)
av_subtitles_extensions = generate_extensions(av_subtitles_files,
                                              'av/subtitles', extra_args)


setup(
    name='av',
    version=version,
    description='Pythonic bindings for libav.',

    author="Mike Boers",
    author_email="pyav@mikeboers.com",

    url="https://github.com/mikeboers/PyAV",

    packages=find_packages(exclude=['build*', 'tests*', 'examples*']),

    zip_safe=False,
    ext_modules = av_extensions + av_video_extensions + av_audio_extensions + av_subtitles_extensions,

    cmdclass={'build_ext': build_ext},
)
