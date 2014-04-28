import errno
from setuptools.command.build_ext import build_ext
from setuptools import setup, find_packages, Extension
from subprocess import Popen, PIPE
import ctypes.util
import os


version = '0.1.0'


# The "extras" to be supplied to every one of our modules.
extension_extra = {
    'include_dirs': ['include'],
}

def update_extend(dst, src):
    for k, v in src.iteritems():
        dst.setdefault(k, []).extend(v)

config_macros = [
    ("PYAV_VERSION", version),
]


def pkg_config(name):
    """Get distutils compatible extension extras via pkg-config."""

    proc = Popen(['pkg-config', '--cflags', '--libs', name], stdout=PIPE, stderr=PIPE)
    raw_config, err = proc.communicate()
    if proc.wait():
        return

    config = {}
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

# Get the config for the libraries that we require.
for name in 'libavformat', 'libavcodec', 'libavutil', 'libswscale':
    config = pkg_config(name)
    if config:
        update_extend(extension_extra, config)
        config_macros.append(('PYAV_HAVE_' + name.upper(), '1'))
    else:
        print 'Could not find', name, 'with pkg-config.'

for name in 'libswresample', 'libavresample':
    config = pkg_config(name)
    if config:
        update_extend(extension_extra, config)
        config_macros.append(('PYAV_HAVE_' + name.upper(), '1'))
        break
else:
    print 'Could not find either of libswresample or libavresample with pkg-config.'


def check_for_func(lib_names, func_name):
    """Define macros if we can find the given function in one of the given libraries."""

    for lib_name in lib_names:

        lib_path = ctypes.util.find_library(lib_name)
        if not lib_path:
            print 'Could not find', lib_name, 'with ctypes.util.find_library'
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
            print 'Could not find', lib_name, 'with ctypes; looked in:'
            print '\n'.join('\t' + path for path in lib_paths)
            continue

        return hasattr(lib, func_name)

# Check for some specific functions.
for libs, func in (
    (['avcodec', 'avutil', 'avcodec'], 'av_frame_get_best_effort_timestamp'),
    (['avformat'], 'avformat_close_input'),
    (['avformat'], 'avformat_alloc_output_context2'),
    (['avutil'], 'av_calloc'),
):
    if check_for_func(libs, func):
        config_macros.append(('PYAV_HAVE_' + func.upper(), '1'))

# Normalize the extras.
extension_extra = dict((k, sorted(set(v))) for k, v in extension_extra.iteritems())


# Construct the modules that we find in the "build/cython" directory.
ext_modules = []
build_dir = os.path.abspath(os.path.join(__file__, '..', 'src'))
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


class my_build_ext(build_ext):

    def run(self):

        include_dir = os.path.join(self.build_temp, 'include')
        pyav_dir = os.path.join(include_dir, 'pyav')
        try:
            os.makedirs(pyav_dir)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise
        header_path = os.path.join(pyav_dir, 'config.h')
        print 'writing', header_path
        with open(header_path, 'w') as fh:
            fh.write('#ifndef PYAV_COMPAT_H\n')
            fh.write('#define PYAV_COMPAT_H\n')
            for k, v in config_macros:
                fh.write('#define %s %s\n' % (k, v))
            fh.write('#endif\n')

        self.include_dirs = self.include_dirs or []
        self.include_dirs.append(include_dir)

        return build_ext.run(self)


setup(

    name='av',
    version=version,
    description='Pythonic bindings for libav.',
    
    author="Mike Boers",
    author_email="pyav@mikeboers.com",
    
    url="https://github.com/mikeboers/PyAV",

    packages=find_packages(exclude=['tests', 'examples']),
    
    zip_safe=False,
    ext_modules=ext_modules,

    cmdclass={'build_ext': my_build_ext},

)
