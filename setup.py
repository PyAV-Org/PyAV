import ctypes.util
from distutils.core import setup, Extension
import os
import subprocess
from subprocess import check_output, CalledProcessError


def update_extend(dst, src):
    for k, v in src.iteritems():
        dst.setdefault(k, []).extend(v)


def pkg_config(name, macro=False):
    """Get distutils compatible extension extras via pkg-config."""

    try:
        raw_config = check_output(['pkg-config', '--cflags', '--libs', name])
    except CalledProcessError:
        return

    config = {}
    if macro:
        macro_name = name[3:] if name.startswith('lib') else name
        config['define_macros'] = [('USE_' + macro_name.upper(), '1')]

    for chunk in raw_config.strip().split():
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

    if isinstance(lib_names, basestring):
        lib_names = [lib_names]

    for lib_name in lib_names:
        lib_path = ctypes.util.find_library(lib_name)
        if not lib_path:
            print 'Could not find', lib_name, 'with ctypes.'
            continue
        lib = ctypes.CDLL(lib_path)
        if hasattr(lib, func_name):
            extension_extra.setdefault('define_macros', []).append(('HAVE_%s' % func_name.upper(), '1'))
            return



extension_extra = {
    'include_dirs': ['headers'],
}


# Get the config for the libraries that we require.
for name in 'libavformat libavcodec libavutil libswscale'.split():
    config = pkg_config(name)
    if not config:
        print 'Could not find', name, 'with pkg-config.'
    update_extend(extension_extra, config)


# Get the config for either swresample OR avresample.
config = pkg_config('libswresample', macro=True)
if not config:
    config = pkg_config('libavresample', macro=True)
if not config:
    print 'Could not find either of libswresample or libavresample with pkg-config.'
update_extend(extension_extra, config)


# Check for some specific functions.
check_for_func(('avformat', 'avutil'), 'av_frame_get_best_effort_timestamp')
check_for_func('avformat', 'avformat_close_input')


# Normalize the extras.
extension_extra = dict((k, sorted(set(v))) for k, v in extension_extra.iteritems())


# Construct the modules that we find in the "build/cython" directory.
ext_modules = []
build_dir = os.path.abspath(os.path.join(__file__, '..', 'build', 'cython'))
for dirname, dirnames, filenames in os.walk(build_dir):
    for filename in filenames:
        if filename.startswith('.') or os.path.splitext(filename)[1] != '.c':
            continue

        path = os.path.join(dirname, filename)
        name = os.path.splitext(os.path.relpath(path, build_dir))[0].replace('/', '.')

        ext_modules.append(Extension(
            name,
            sources=[path],
            **extension_extra
        ))


setup(

    name='av',
    version='0.1',
    description='Pythonic bindings for libav.',
    
    author="Mike Boers",
    author_email="pyav@mikeboers.com",
    
    url="https://github.com/mikeboers/PyAV",

    packages=["av"],
    
    ext_modules=ext_modules,

)
