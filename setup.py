from __future__ import print_function

from distutils.ccompiler import new_compiler as _new_compiler, LinkError, CompileError
from distutils.command.clean import clean, log
from distutils.core import Command
from distutils.dir_util import remove_tree
from distutils.errors import DistutilsExecError
from distutils.msvccompiler import MSVCCompiler
from setuptools import setup, find_packages, Extension, Distribution
from setuptools.command.build_ext import build_ext
from distutils.command.clean import clean, log
from distutils.dir_util import remove_tree
from subprocess import Popen, PIPE
import errno
import itertools
import json
import os
import platform
import re
import sys

try:
    # This depends on _winreg, which is not availible on not-Windows.
    from distutils.msvc9compiler import MSVCCompiler as MSVC9Compiler
except ImportError:
    MSVC9Compiler = None
    msvc_compiler_classes = (MSVCCompiler, )
else:
    msvc_compiler_classes = (MSVCCompiler, MSVC9Compiler)

try:
    from Cython.Build import cythonize
except ImportError:
    # We don't need Cython all the time; just for building from original source.
    cythonize = None


is_py3 = sys.version_info[0] >= 3


# We will embed this metadata into the package so it can be recalled for debugging.
version = '0.3.1'
git_commit, _ = Popen(['git', 'describe', '--tags'], stdout=PIPE, stderr=PIPE).communicate()
git_commit = git_commit.strip()


def get_library_config(name):
    """Get distutils-compatible extension extras for the given library.

    This requires ``pkg-config``.

    """
    try:
        proc = Popen(['pkg-config', '--cflags', '--libs', name], stdout=PIPE, stderr=PIPE)
    except OSError:
        print('pkg-config is required for building PyAV')
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


def is_msvc(cc=None):
    cc = _new_compiler() if cc is None else cc
    return isinstance(cc, msvc_compiler_classes)


# The "extras" to be supplied to every one of our modules.
# This is expanded heavily by the `config` command.
extension_extra = {
    'include_dirs': ['include'], # These are PyAV's includes.
    'libraries'   : [],
    'library_dirs': [],
}

# The macros which describe what functions and structure members we have
# from the underlying libraries. This is expanded heavily by `reflect` command.
config_macros = [
    ("PYAV_VERSION", version),
    ("PYAV_VERSION_STR", '"%s"' % version),
    ("PYAV_COMMIT_STR", '"%s"' % (git_commit or 'unknown-commit'))
]


def dump_config():
    """Print out all the config information we have so far (for debugging)."""
    print('PyAV:', version, git_commit)
    print('Python:', sys.version.encode('unicode_escape' if is_py3 else 'string-escape'))
    print('platform:', platform.platform())
    print('extension_extra:')
    for k, vs in extension_extra.items():
        print('\t%s: %s' % (k, [x.encode('utf8') for x in vs]))
    print('config_macros:')
    for x in config_macros:
        print('\t%s=%s' % x)





if os.name == 'nt':


    if is_msvc():
        config_macros.append(('inline', '__inline'))
    # Since we're shipping a self contained unit on windows, we need to mark
    # the package as such. On other systems, let it be universal.
    class BinaryDistribution(Distribution):
        def is_pure(self):
            return False
    distclass = BinaryDistribution

else:

    distclass = Distribution



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
    cc = _new_compiler(*args, **kwargs)
    if kwargs.pop('silent', True):
        cc.spawn = _CCompiler_spawn_silent
    return cc


def compile_check(code, name, includes=None, include_dirs=None, libraries=None,
                  library_dirs=None, link=True, compiler=None):
    """Check that we can compile and link the given source.

    Caches results; delete the ``build`` directory to reset.

    Writes source (``*.c``), builds (``*.o``), executables (``*.out``),
    and cached results (``*.json``) in ``build/temp.$platform/reflection``.

    """
    exec_path = name + '.out'
    source_path = name + '.c'
    result_path = name + '.json'

    if os.path.exists(result_path):
        try:
            return json.load(open(result_path))
        except ValueError:
            pass

    cc = new_compiler(compiler=compiler)

    with open(source_path, 'w') as fh:
        if is_msvc(cc):
            fh.write("#define inline __inline\n")
        for include in includes or ():
            fh.write('#include "%s"\n' % include)
        fh.write('main(int argc, char **argv)\n{ %s; }\n' % code)


    try:
        objects = cc.compile([source_path], include_dirs=include_dirs)
        if link:
            cc.link_executable(objects, exec_path, libraries=libraries, library_dirs=library_dirs)
    except (CompileError, LinkError, TypeError):
        res = False
    else:
        res = True

    with open(result_path, 'w') as fh:
        fh.write(json.dumps(res))

    return res


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
                'libraries':    ['avformat', 'avcodec', 'avdevice', 'avutil',
                                 'swscale'],
                'library_dirs': [],
                'include_dirs': []
            }
            config['libraries'].append('swresample')
            config_macros.append(('PYAV_HAVE_LIBSWRESAMPLE', 1))
            update_extend(extension_extra, config)
            for ext in self.distribution.ext_modules:
                for key, value in extension_extra.items():
                    setattr(ext, key, value)
            return

        # We're using pkg-config:
        errors = []

        # Get the config for the libraries that we require.
        for name in 'libavformat', 'libavcodec', 'libavdevice', 'libavutil', 'libavfilter', 'libswscale':
            config = get_library_config(name)
            if config:
                update_extend(extension_extra, config)
                # We don't need macros for these, since they all must exist.
            else:
                errors.append('Could not find ' + name + ' with pkg-config.')

        # Get the config for either swresample OR avresample.
        for name in 'libswresample', 'libavresample':
            config = get_library_config(name)
            if config:
                update_extend(extension_extra, config)
                config_macros.append(('PYAV_HAVE_' + name.upper(), '1'))
                break
        else:
            errors.append('Could not find either libswresample or libavresample with pkg-config.')

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

        for ext in self.distribution.ext_modules:
            for key, value in extension_extra.items():
                setattr(ext, key, value)



class ReflectCommand(Command):

    sep_by = " (separated by '%s')" % os.pathsep
    user_options = [
        ('build-temp=', 't', "directory for temporary files (build by-products)"),
        ('include-dirs=', 'I', "list of directories to search for header files" + sep_by),
        ('libraries=', 'l', "external C libraries to link with"),
        ('library-dirs=', 'L', "directories to search for external C libraries" + sep_by),
        ('no-pkg-config', None, "do not use pkg-config to configure dependencies"),
        ('compiler=', 'c', "specify the compiler type"),
    ]

    boolean_options = ['no-pkg-config']

    def initialize_options(self):
        self.compiler = None
        self.build_temp = None
        self.include_dirs = None
        self.libraries = None
        self.library_dirs = None
        self.no_pkg_config = None

    def finalize_options(self):
        self.set_undefined_options('build',
            ('build_temp', 'build_temp'),
            ('compiler', 'compiler'),
        )
        self.set_undefined_options('build_ext',
            ('include_dirs', 'include_dirs'),
            ('libraries', 'libraries'),
            ('library_dirs', 'library_dirs'),
            ('no_pkg_config', 'no_pkg_config'),
        )
        # Need to do this ourself, since no inheritance from build_ext:
        try:
            str_base = basestring
        except NameError:
            str_base = str
        if isinstance(self.include_dirs, str_base):
            self.include_dirs = self.include_dirs.split(os.pathsep)
        if isinstance(self.library_dirs, str_base):
            self.library_dirs = str.split(self.library_dirs, os.pathsep)

    def run(self):

        # Propagate options
        obj = self.distribution.get_command_obj('config')
        obj.no_pkg_config = self.no_pkg_config
        obj.compiler = self.compiler
        self.run_command('config')

        tmp_dir = os.path.join(self.build_temp, 'reflection')
        try:
            os.makedirs(tmp_dir)
        except OSError as e:
            if e.errno != errno.EEXIST:
                raise

        found = []

        reflection_includes = [
            'libavcodec/avcodec.h',
            'libavformat/avformat.h',
            'libavutil/avutil.h',
        ]

        config = extension_extra.copy()
        config['include_dirs'] += self.include_dirs
        config['libraries'] += self.libraries
        config['library_dirs'] += self.library_dirs

        # Check for some specific functions.
        for func_name in (

            'avformat_open_input', # Canary that should exist.
            'pyav_function_should_not_exist', # Canary that should not exist.

            # This we actually care about:
            'av_calloc',
            'av_frame_get_best_effort_timestamp',
            'avformat_alloc_output_context2',
            'avformat_close_input',

        ):
            print("looking for %s... " % func_name, end='')
            if compile_check(
                name=os.path.join(tmp_dir, func_name),
                code='%s()' % func_name,
                libraries=config['libraries'],
                library_dirs=config['library_dirs'],
                compiler=self.compiler,
            ):
                print('found')
                found.append(func_name)
            else:
                print('missing')

        for struct_name, member_name in (

            ('AVStream', 'index'), # Canary that should exist
            ('PyAV', 'struct_should_not_exist'), # Canary that should not exist.

            # Things we actually care about:
            ('AVFrame', 'mb_type'),

        ):
            print("looking for %s.%s... " % (struct_name, member_name), end='')
            if compile_check(
                name=os.path.join(tmp_dir, '%s.%s' % (struct_name, member_name)),
                code='struct %s x; x.%s;' % (struct_name, member_name),
                includes=reflection_includes,
                include_dirs=config['include_dirs'],
                link=False,
                compiler=self.compiler,
            ):
                print('found')
                # Double-unscores for members.
                found.append('%s__%s' % (struct_name, member_name))
            else:
                print('missing')

        canaries = {
            'pyav_function_should_not_exist': ('function', False),
            'PyAV__struct_should_not_exist': ('member', False),
            'avformat_open_input': ('function', True),
            'AVStream__index': ('member', True),
        }

        # Create macros for the things that we found.
        # There is potential for naming collisions between functions and
        # structure members, but until we actually have one, we won't
        # worry about it.
        config_macros.extend(
            ('PYAV_HAVE_%s' % name.upper(), '1')
            for name in found
            if name not in canaries
        )


        # Make sure our canaries report back properly.
        for name, (type_, should_exist) in canaries.items():
            if should_exist != (name in found):
                print('\nWe %s `%s` in the libraries.' % (
                    'didn\'t find' if should_exist else 'found',
                    name
                ))
                print('We look for it only as a sanity check to make sure the build\n'
                      'process is working as expected. It is not, so we must abort.\n'
                      '\n'
                      'Please open a ticket at https://github.com/mikeboers/PyAV/issues\n'
                      'with the folowing information:\n')
                dump_config()
                exit(1)



class DoctorCommand(Command):

    user_options = []
    def initialize_options(self):
        pass
    def finalize_options(self):
        pass

    def run(self):
        self.run_command('config')
        self.run_command('reflect')
        print()
        dump_config()


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

        user_options = build_ext.user_options + [
            ('ffmpeg-dir=', None,
             "directory containing lib and include folders of ffmpeg")]

        def initialize_options(self):
            build_ext.initialize_options(self)
            self.ffmpeg_dir = None

        def finalize_options(self):
            build_ext.finalize_options(self)
            if self.ffmpeg_dir and os.path.exists(self.ffmpeg_dir):
                sublib = os.path.join(self.ffmpeg_dir, 'lib')
                subinc = os.path.join(self.ffmpeg_dir, 'include')
                if os.path.exists(sublib):
                    unique_extend(self.library_dirs, [sublib])
                else:
                    unique_extend(self.library_dirs, [self.ffmpeg_dir])
                if os.path.exists(subinc):
                    unique_extend(self.include_dirs, [subinc])
                else:
                    unique_extend(self.include_dirs, [self.ffmpeg_dir])

    def run(self):

        # Propagate build options to reflect
        obj = self.distribution.get_command_obj('reflect')
        obj.compiler = self.compiler
        obj.no_pkg_config = self.no_pkg_config
        obj.include_dirs = self.include_dirs
        obj.libraries = self.libraries
        obj.library_dirs = self.library_dirs

        self.run_command('reflect')

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
            for k, v in config_macros:
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
        'clean': CleanCommand,
        'config': ConfigCommand,
        'cythonize': CythonizeCommand,
        'doctor': DoctorCommand,
        'reflect': ReflectCommand,
    },

    test_suite='nose.collector',

    entry_points={
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
       'Programming Language :: Python :: 3.4',
       'Topic :: Software Development :: Libraries :: Python Modules',
       'Topic :: Multimedia :: Sound/Audio',
       'Topic :: Multimedia :: Sound/Audio :: Conversion',
       'Topic :: Multimedia :: Video',
       'Topic :: Multimedia :: Video :: Conversion',
   ],

    distclass=distclass,

)
