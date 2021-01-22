from distutils.ccompiler import new_compiler as _new_compiler
from distutils.command.clean import clean, log
from distutils.core import Command
from distutils.dir_util import remove_tree
from distutils.errors import DistutilsExecError
from distutils.msvccompiler import MSVCCompiler
from setuptools import setup, find_packages, Extension, Distribution
from setuptools.command.build_ext import build_ext
from shlex import quote
from subprocess import Popen, PIPE
import argparse
import errno
import os
import platform
import re
import shlex
import sys

try:
    # This depends on _winreg, which is not availible on not-Windows.
    from distutils.msvc9compiler import MSVCCompiler as MSVC9Compiler
except ImportError:
    MSVC9Compiler = None
try:
    from distutils._msvccompiler import MSVCCompiler as MSVC14Compiler
except ImportError:
    MSVC14Compiler = None

try:
    from Cython import __version__ as cython_version
    from Cython.Build import cythonize
except ImportError:
    cythonize = None
else:
    # We depend upon some features in Cython 0.27; reject older ones.
    if tuple(map(int, cython_version.split('.'))) < (0, 27):
        print("Cython {} is too old for PyAV; ignoring it.".format(cython_version))
        cythonize = None


# We will embed this metadata into the package so it can be recalled for debugging.
version = open('VERSION.txt').read().strip()
try:
    git_commit, _ = Popen(['git', 'describe', '--tags'], stdout=PIPE, stderr=PIPE).communicate()
except OSError:
    git_commit = None
else:
    git_commit = git_commit.decode().strip()


_cflag_parser = argparse.ArgumentParser(add_help=False)
_cflag_parser.add_argument('-I', dest='include_dirs', action='append')
_cflag_parser.add_argument('-L', dest='library_dirs', action='append')
_cflag_parser.add_argument('-l', dest='libraries', action='append')
_cflag_parser.add_argument('-D', dest='define_macros', action='append')
_cflag_parser.add_argument('-R', dest='runtime_library_dirs', action='append')
def parse_cflags(raw_cflags):
    raw_args = shlex.split(raw_cflags.strip())
    args, unknown = _cflag_parser.parse_known_args(raw_args)
    config = {k: v or [] for k, v in args.__dict__.items()}
    for i, x in enumerate(config['define_macros']):
        parts = x.split('=', 1)
        value = x[1] or None if len(x) == 2 else None
        config['define_macros'][i] = (parts[0], value)
    return config, ' '.join(quote(x) for x in unknown)

def get_library_config(name):
    """Get distutils-compatible extension extras for the given library.

    This requires ``pkg-config``.

    """
    try:
        proc = Popen(['pkg-config', '--cflags', '--libs', name], stdout=PIPE, stderr=PIPE)
    except OSError:
        print('pkg-config is required for building PyAV')
        exit(1)

    raw_cflags, err = proc.communicate()
    if proc.wait():
        return

    known, unknown = parse_cflags(raw_cflags.decode('utf8'))
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
FFMPEG_DIR = None
for i, arg in enumerate(sys.argv):
    if arg.startswith('--ffmpeg-dir='):
        FFMPEG_DIR = arg.split('=')[1]
        break

if FFMPEG_DIR is not None:
    # delete the --ffmpeg-dir arg so that distutils does not see it
    del sys.argv[i]
    if not os.path.isdir(FFMPEG_DIR):
        print('The specified ffmpeg directory does not exist')
        exit(1)
else:
    # Check the environment variable FFMPEG_DIR
    FFMPEG_DIR = os.environ.get('FFMPEG_DIR')
    if FFMPEG_DIR is not None:
        if not os.path.isdir(FFMPEG_DIR):
            FFMPEG_DIR = None

if FFMPEG_DIR is not None:
    ffmpeg_lib = os.path.join(FFMPEG_DIR, 'lib')
    ffmpeg_include = os.path.join(FFMPEG_DIR, 'include')
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
    'include_dirs': ['include'] + ffmpeg_include,  # The first are PyAV's includes.
    'libraries'   : [],
    'library_dirs': ffmpeg_lib,
}

# The macros which describe the current PyAV version.
config_macros = {
    "PYAV_VERSION": version,
    "PYAV_VERSION_STR": '"%s"' % version,
    "PYAV_COMMIT_STR": '"%s"' % (git_commit or 'unknown-commit'),
}


def dump_config():
    """Print out all the config information we have so far (for debugging)."""
    print('PyAV:', version, git_commit or '(unknown commit)')
    print('Python:', sys.version.encode('unicode_escape').decode())
    print('platform:', platform.platform())
    print('extension_extra:')
    for k, vs in extension_extra.items():
        print('\t%s: %s' % (k, [x.encode('utf8') for x in vs]))
    print('config_macros:')
    for x in sorted(config_macros.items()):
        print('\t%s=%s' % x)


# Monkey-patch for CCompiler to be silent.
def _CCompiler_spawn_silent(cmd, dry_run=None):
    """Spawn a process, and eat the stdio."""
    proc = Popen(cmd, stdout=PIPE, stderr=PIPE)
    out, err = proc.communicate()
    if proc.returncode:
        raise DistutilsExecError(err)

def new_compiler(*args, **kwargs):
    """Create a C compiler.

    :param bool silent: Eat all stdio? Defaults to ``True``.

    All other arguments passed to ``distutils.ccompiler.new_compiler``.

    """
    make_silent = kwargs.pop('silent', True)
    cc = _new_compiler(*args, **kwargs)
    # If MSVC10, initialize the compiler here and add /MANIFEST to linker flags.
    # See Python issue 4431 (https://bugs.python.org/issue4431)
    if is_msvc(cc):
        from distutils.msvc9compiler import get_build_version
        if get_build_version() == 10:
            cc.initialize()
            for ldflags in [cc.ldflags_shared, cc.ldflags_shared_debug]:
                unique_extend(ldflags, ['/MANIFEST'])
        # If MSVC14, do not silence. As msvc14 requires some custom
        # steps before the process is spawned, we can't monkey-patch this.
        elif get_build_version() == 14:
            make_silent = False
    # monkey-patch compiler to suppress stdout and stderr.
    if make_silent:
        cc.spawn = _CCompiler_spawn_silent
    return cc


_msvc_classes = tuple(filter(None, (MSVCCompiler, MSVC9Compiler, MSVC14Compiler)))
def is_msvc(cc=None):
    cc = _new_compiler() if cc is None else cc
    return isinstance(cc, _msvc_classes)


if os.name == 'nt':

    if is_msvc():
        config_macros['inline'] = '__inline'

    # Since we're shipping a self contained unit on Windows, we need to mark
    # the package as such. On other systems, let it be universal.
    class BinaryDistribution(Distribution):
        def is_pure(self):
            return False

    distclass = BinaryDistribution

else:

    # Nothing to see here.
    distclass = Distribution


# Monkey-patch Cython to not overwrite embedded signatures.
if cythonize:

    from Cython.Compiler.AutoDocTransforms import EmbedSignature

    old_embed_signature = EmbedSignature._embed_signature
    def new_embed_signature(self, sig, doc):

        # Strip any `self` parameters from the front.
        sig = re.sub(r'\(self(,\s+)?', '(', sig)

        # If they both start with the same signature; skip it.
        if sig and doc:
            new_name = sig.split('(')[0].strip()
            old_name = doc.split('(')[0].strip()
            if new_name == old_name:
                return doc
            if new_name.endswith('.' + old_name):
                return doc

        return old_embed_signature(self, sig, doc)

    EmbedSignature._embed_signature = new_embed_signature


# Construct the modules that we find in the "av" directory.
ext_modules = []
for dirname, dirnames, filenames in os.walk('av'):
    for filename in filenames:

        # We are looing for Cython sources.
        if filename.startswith('.') or os.path.splitext(filename)[1] != '.pyx':
            continue

        pyx_path = os.path.join(dirname, filename)
        base = os.path.splitext(pyx_path)[0]

        # Need to be a little careful because Windows will accept / or \
        # (where os.sep will be \ on Windows).
        mod_name = base.replace('/', '.').replace(os.sep, '.')

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
        ))


class ConfigCommand(Command):

    user_options = [
        ('no-pkg-config', None,
         "do not use pkg-config to configure dependencies"),
        ('verbose', None,
         "dump out configuration"),
        ('compiler=', 'c',
         "specify the compiler type"), ]

    boolean_options = ['no-pkg-config']

    def initialize_options(self):
        self.compiler = None
        self.no_pkg_config = None

    def finalize_options(self):
        self.set_undefined_options('build',
            ('compiler', 'compiler'),)
        self.set_undefined_options('build_ext',
            ('no_pkg_config', 'no_pkg_config'),)

    def run(self):

        # For some reason we get the feeling that CFLAGS is not respected, so we parse
        # it here. TODO: Leave any arguments that we can't figure out.
        for name in 'CFLAGS', 'LDFLAGS':
            known, unknown = parse_cflags(os.environ.pop(name, ''))
            if unknown:
                print("Warning: We don't understand some of {} (and will leave it in the envvar): {}".format(name, unknown))
                os.environ[name] = unknown
            update_extend(extension_extra, known)

        if is_msvc(new_compiler(compiler=self.compiler)):
            # Assume we have to disable /OPT:REF for MSVC with ffmpeg
            config = {
                'extra_link_args': ['/OPT:NOREF'],
            }
            update_extend(extension_extra, config)

        # Check if we're using pkg-config or not
        if self.no_pkg_config:
            # Simply assume we have everything we need!
            config = {
                'libraries':    ['avformat', 'avcodec', 'avdevice', 'avutil', 'avfilter',
                                 'swscale', 'swresample'],
                'library_dirs': [],
                'include_dirs': []
            }
            update_extend(extension_extra, config)
            for ext in self.distribution.ext_modules:
                for key, value in extension_extra.items():
                    setattr(ext, key, value)
            return

        # We're using pkg-config:
        errors = []

        # Get the config for the libraries that we require.
        for name in 'libavformat', 'libavcodec', 'libavdevice', 'libavutil', 'libavfilter', 'libswscale', 'libswresample':
            config = get_library_config(name)
            if config:
                update_extend(extension_extra, config)
                # We don't need macros for these, since they all must exist.
            else:
                errors.append('Could not find ' + name + ' with pkg-config.')

        if self.verbose:
            dump_config()

        # Don't continue if we have errors.
        # TODO: Warn Ubuntu 12 users that they can't satisfy requirements with the
        # default package sources.
        if errors:
            print('\n'.join(errors))
            exit(1)

        # Normalize the extras.
        extension_extra.update(
            dict((k, sorted(set(v))) for k, v in extension_extra.items())
        )

        # Apply them.
        for ext in self.distribution.ext_modules:
            for key, value in extension_extra.items():
                setattr(ext, key, value)


class CleanCommand(clean):

    user_options = clean.user_options + [
        ('sources', None,
         "remove Cython build output (C sources)")]

    boolean_options = clean.boolean_options + ['sources']

    def initialize_options(self):
        clean.initialize_options(self)
        self.sources = None

    def run(self):
        clean.run(self)
        if self.sources:
            if os.path.exists('src'):
                remove_tree('src', dry_run=self.dry_run)
            else:
                log.info("'%s' does not exist -- can't clean it", 'src')


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
            if any(s.endswith('.pyx') for s in ext.sources):
                if is_msvc():
                    ext.define_macros.append(('inline', '__inline'))
                new_ext = cythonize(
                    ext,
                    compiler_directives=dict(
                        c_string_type='str',
                        c_string_encoding='ascii',
                        embedsignature=True,
                        language_level=2,
                    ),
                    build_dir='src',
                    include_path=ext.include_dirs,
                )[0]
                ext.sources = new_ext.sources


class BuildExtCommand(build_ext):

    if os.name != 'nt':
        user_options = build_ext.user_options + [
            ('no-pkg-config', None,
             "do not use pkg-config to configure dependencies")]

        boolean_options = build_ext.boolean_options + ['no-pkg-config']

        def initialize_options(self):
            build_ext.initialize_options(self)
            self.no_pkg_config = None
    else:
        no_pkg_config = 1

    def run(self):

        # Propagate build options to config
        obj = self.distribution.get_command_obj('config')
        obj.compiler = self.compiler
        obj.no_pkg_config = self.no_pkg_config
        obj.include_dirs = self.include_dirs
        obj.libraries = self.libraries
        obj.library_dirs = self.library_dirs

        self.run_command('config')

        # We write a header file containing everything we have discovered by
        # inspecting the libraries which exist. This is the main mechanism we
        # use to detect differenced between FFmpeg and Libav.

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
            for k, v in sorted(config_macros.items()):
                fh.write('#define %s %s\n' % (k, v))
            fh.write('#endif\n')

        self.include_dirs = self.include_dirs or []
        self.include_dirs.append(include_dir)
        # Propagate config to cythonize.
        for i, ext in enumerate(self.distribution.ext_modules):
            unique_extend(ext.include_dirs, self.include_dirs)
            unique_extend(ext.library_dirs, self.library_dirs)
            unique_extend(ext.libraries, self.libraries)

        self.run_command('cythonize')
        build_ext.run(self)


setup(

    name='av',
    version=version,
    description="Pythonic bindings for FFmpeg's libraries.",

    author="Mike Boers",
    author_email="pyav@mikeboers.com",

    url="https://github.com/PyAV-Org/PyAV",

    packages=find_packages(exclude=['build*', 'examples*', 'scratchpad*', 'tests*']),

    zip_safe=False,
    ext_modules=ext_modules,

    cmdclass={
        'build_ext': BuildExtCommand,
        'clean': CleanCommand,
        'config': ConfigCommand,
        'cythonize': CythonizeCommand,
    },

    test_suite='tests',

    entry_points={
        'console_scripts': [
            'pyav = av.__main__:main',
        ],
    },

    classifiers=[
       'Development Status :: 5 - Production/Stable',
       'Intended Audience :: Developers',
       'License :: OSI Approved :: BSD License',
       'Natural Language :: English',
       'Operating System :: MacOS :: MacOS X',
       'Operating System :: POSIX',
       'Operating System :: Unix',
       'Operating System :: Microsoft :: Windows',
       'Programming Language :: Cython',
       'Programming Language :: Python :: 3.5',
       'Programming Language :: Python :: 3.6',
       'Programming Language :: Python :: 3.7',
       'Programming Language :: Python :: 3.8',
       'Programming Language :: Python :: 3.9',
       'Topic :: Software Development :: Libraries :: Python Modules',
       'Topic :: Multimedia :: Sound/Audio',
       'Topic :: Multimedia :: Sound/Audio :: Conversion',
       'Topic :: Multimedia :: Video',
       'Topic :: Multimedia :: Video :: Conversion',
   ],

    distclass=distclass,

)
