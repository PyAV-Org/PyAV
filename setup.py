from __future__ import print_function

from distutils.core import Command
from setuptools import setup, find_packages, Extension, Distribution
from setuptools.command.build_ext import build_ext
from subprocess import Popen, PIPE
import ctypes.util
import errno
import os
import re

try:
    from Cython.Build import cythonize
except ImportError:
    cythonize = None


version = '0.2.2'
proc = Popen(['git', 'describe', '--tags'], stdout=PIPE, stderr=PIPE)
commit, _ = proc.communicate()
commit = commit.strip()


def library_config(name):
    """Get distutils compatible extension extras for the given library.

    When availible, this uses ``pkg-config``.

    """

    try:
        proc = Popen(['pkg-config', '--cflags', '--libs', name], stdout=PIPE, stderr=PIPE)
    except OSError:
        print('pkg-config is required for building PyAV; aborting!')
        exit(1)

    raw_config, err = proc.communicate()
    if proc.wait():
        return

    config = {}
    for chunk in raw_config.decode('utf8').strip().split():
        if chunk.startswith('-I'):
            config.setdefault('include_dirs', []).append(chunk[2:])
        elif chunk.startswith('-L'):
            config.setdefault('library_dirs', []).append(chunk[2:])
        elif chunk.startswith('-l'):
            config.setdefault('libraries', []).append(chunk[2:])
        elif chunk.startswith('-D'):
            name = chunk[2:].split('=')[0]
            config.setdefault('define_macros', []).append((name, None))

    return config


def check_for_func(lib_names, func_name):
    """Define macros if we can find the given function in one of the given libraries."""

    for lib_name in lib_names:

        lib_path = ctypes.util.find_library(lib_name)
        if not lib_path:
            continue

        # Open the lib. Look in the path returned by find_library, but also all
        # the paths returned by pkg-config (since we don't get an absolute path
        # on linux).
        lib_paths = [lib_path]
        lib_paths.extend(
            os.path.join(root, os.path.basename(lib_path))
            for root in set(extension_extra.get('library_dirs', []))
        )
        for lib_path in lib_paths:
            try:
                lib = ctypes.CDLL(lib_path)
                break
            except OSError:
                pass
        else:
            print('Could not find', lib_name, 'with ctypes; looked in:')
            print('\n'.join('\t' + path for path in lib_paths))
            continue

        return hasattr(lib, func_name)

    else:
        print('Could not find %r with ctypes.util.find_library' % (lib_names, ))
        print('Some libraries can not be found for inspection; aborting!')
        exit(2)


# The "extras" to be supplied to every one of our modules.
extension_extra = {
    'include_dirs': ['include'],
}

def update_extend(dst, src):
    for k, v in src.items():
        dst.setdefault(k, []).extend(v)

config_macros = [
    ("PYAV_VERSION", version),
    ("PYAV_VERSION_STR", '"%s"' % version),
    ("PYAV_COMMIT_STR", '"%s"' % (commit or 'unknown-commit'))
]

is_missing_libraries = False


# Get the config for the libraries that we require.
for name in 'libavformat', 'libavcodec', 'libavdevice', 'libavutil', 'libswscale':
    config = library_config(name)
    if config:
        update_extend(extension_extra, config)
        config_macros.append(('PYAV_HAVE_' + name.upper(), '1'))
    else:
        print('Could not find', name, 'with pkg-config.')
        is_missing_libraries = True

# Get the config for either swresample OR avresample.
for name in 'libswresample', 'libavresample':
    config = library_config(name)
    if config:
        update_extend(extension_extra, config)
        config_macros.append(('PYAV_HAVE_' + name.upper(), '1'))
        break
else:
    print('Could not find either of libswresample or libavresample with pkg-config.')
    is_missing_libraries = True


if is_missing_libraries:
    # TODO: Warn Ubuntu 12 users that they can't satisfy requirements with the
    # default package sources.
    print('Some required libraries are missing, and PyAV cannot be built; aborting!')
    exit(1)

# ffmpeg/libav library names are different on windows and unix.
if os.name == 'nt':
    libnames = {'avformat':'avformat-56', 'avutil':'avutil-54',
                'avcodec':'avcodec-56'}
    dlls = ['avcodec-56.dll', 'avdevice-56.dll', 'avfilter-5.dll',
            'avformat-56.dll', 'avutil-54.dll', 'postproc-53.dll',
            'swresample-1.dll', 'swscale-3.dll',
            'libgcc_s_dw2-1.dll', 'libwinpthread-1.dll']

    # Ensure the libraries exist in the av-folder for proper wheel packaging
    for dll in dlls:
        if not os.path.isfile(os.path.join('av',dll)):
            raise AssertionError("Missing DLL, please copy {} to the 'av' " \
                                 "directory, next to the pxd files".format(dll))

    # Since we're shipping a self contained unit on windows, we need to mark
    # the package as such. On other systems, let it be universal.
    class BinaryDistribution(Distribution):
        def is_pure(self):
            return False
    distclass = BinaryDistribution

else:
    libnames = {'avformat':'avformat', 'avutil':'avutil', 'avcodec':'avcodec'}
    dlls = []
    distclass = Distribution

# Check for some specific functions.
for libs, func in (
    ([libnames['avformat'], libnames['avutil'], libnames['avcodec']],
        'av_frame_get_best_effort_timestamp'),
    ([libnames['avformat']], 'avformat_close_input'),
    ([libnames['avformat']], 'avformat_alloc_output_context2'),
    ([libnames['avutil']], 'av_calloc'),
):
    if check_for_func(libs, func):
        config_macros.append(('PYAV_HAVE_' + func.upper(), '1'))


# Normalize the extras.
extension_extra = dict((k, sorted(set(v))) for k, v in extension_extra.items())


# Construct the modules that we find in the "av" directory.
ext_modules = []
for dirname, dirnames, filenames in os.walk('av'):
    for filename in filenames:

        # We are looing for Cython sources.
        if filename.startswith('.') or os.path.splitext(filename)[1] != '.pyx':
            continue

        pyx_path = os.path.join(dirname, filename)
        base = os.path.splitext(pyx_path)[0]
        mod_name = base.replace('/', '.')
        c_path = os.path.join('src', base + '.c')

        # We go with the C sources if Cython is not installed, and fail if
        # those also don't exist. We can't `cythonize` here though, since the
        # `pyav/include.h` must be generated (by `build_ext`) first.
        if not cythonize and not os.path.exists(c_path):
            print('Cython is required to build PyAV from raw sources.')
            print('Please `pip install Cython`.')
            exit(3)
        ext_modules.append(Extension(
            mod_name,
            sources=[c_path if not cythonize else pyx_path],
            **extension_extra
        ))


class CythonizeCommand(Command):

    user_options = []

    def initialize_options(self):
        self.extensions = None

    def finalize_options(self):
        self.extensions = self.distribution.ext_modules

    def run(self):

        # Cythonize, if required. We do it individually since we must update
        # the existing extension instead of replacing them all.
        for i, ext in enumerate(self.extensions[:]):
            if any(s.endswith('.pyx') for s in ext.sources):
                new_ext = cythonize(ext,
                    # Keep these in sync with the Makefile cythonize target.
                    compiler_directives=dict(
                        c_string_type='str',
                        c_string_encoding='ascii',
                    ),
                    build_dir='src',
                    include_path=ext.include_dirs,
                    embed=True,
                )[0]
                ext.sources = new_ext.sources


class BuildExtCommand(build_ext):

    # fix incorrect pyd/dll init export function names produced on windows
    # for the .def files.
    if os.name == 'nt':
        def get_export_symbols (self, ext):
            initfunc_name = "init" + ext.name.split('\\')[-1]
            if initfunc_name not in ext.export_symbols:
                ext.export_symbols.append(initfunc_name)
            return ext.export_symbols

    def run(self):

        # We write a header file containing everything we have discovered by
        # inspecting the libraries which exist. This is the main mechanism we
        # use to detect differenced between FFmpeg anf Libav.

        include_dir = os.path.join(self.build_temp, 'include')
        pyav_dir = os.path.join(include_dir, 'pyav')
        try:
            os.makedirs(pyav_dir)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise
        header_path = os.path.join(pyav_dir, 'config.h')
        print('writing', header_path)
        with open(header_path, 'w') as fh:
            fh.write('#ifndef PYAV_COMPAT_H\n')
            fh.write('#define PYAV_COMPAT_H\n')
            for k, v in config_macros:
                fh.write('#define %s %s\n' % (k, v))
            fh.write('#endif\n')

        self.include_dirs = self.include_dirs or []
        self.include_dirs.append(include_dir)

        self.run_command('cythonize')

        return build_ext.run(self)


setup(

    name='av',
    version=version,
    description='Pythonic bindings for FFmpeg/Libav.',
    
    author="Mike Boers",
    author_email="pyav@mikeboers.com",
    
    url="https://github.com/mikeboers/PyAV",

    packages=find_packages(exclude=['build*', 'tests*', 'examples*']),
    
    zip_safe=False,
    ext_modules=ext_modules,

    cmdclass={
        'build_ext': BuildExtCommand,
        'cythonize': CythonizeCommand,
    },

    test_suite = 'nose.collector',

    entry_points = {
        'console_scripts': [
            'pyav = av.__main__:main',
        ],
    },
    
    classifiers=[
       'Development Status :: 3 - Alpha',
       'Intended Audience :: Developers',
       'License :: OSI Approved :: BSD License',
       'Natural Language :: English',
       'Operating System :: MacOS :: MacOS X',
       'Operating System :: POSIX',
       'Operating System :: Unix',
       'Programming Language :: Cython',
       'Programming Language :: Python :: 2.6',
       'Programming Language :: Python :: 2.7',
       'Programming Language :: Python :: 3.3',
       'Programming Language :: Python :: 2.4',
       'Topic :: Software Development :: Libraries :: Python Modules',
       'Topic :: Multimedia :: Sound/Audio',
       'Topic :: Multimedia :: Sound/Audio :: Conversion',
       'Topic :: Multimedia :: Video',
       'Topic :: Multimedia :: Video :: Conversion',
   ],

    distclass=distclass,
    package_data={ 'av': dlls, },

)
