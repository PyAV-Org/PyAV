from __future__ import print_function

from distutils.ccompiler import new_compiler as _new_compiler, LinkError, CompileError
from distutils.core import Command
from distutils.errors import DistutilsExecError
from setuptools import setup, find_packages, Extension, Distribution
from setuptools.command.build_ext import build_ext
from subprocess import Popen, PIPE, STDOUT
import errno
import itertools
import json
import os
import platform
import re
import sys


try:
    from Cython.Build import cythonize
except ImportError:
    # We don't need Cython all the time; just for building from original source.
    cythonize = None


# We will embed this metadata into the package so it can be recalled for debugging.
version = '0.2.4'
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
    print('Python:', sys.version.encode('string-escape'))
    print('platform:', platform.platform())
    print('extension_extra:')
    for k, vs in extension_extra.items():
        print('\t%s: %s' % (k, [x.encode('utf8') for x in vs]))
    print('config_macros:')
    for x in config_macros:
        print('\t%s=%s' % x)





if os.name == 'nt':

    print(
        'Building on Windows is not officially supported, and is likely broken\n'
        'due to a refactoring of the build process.\n\n'
        'Please read http://mikeboers.github.io/PyAV/installation.html#on-windows\n'
        'and document issues in https://github.com/mikeboers/PyAV/issues/38'
    )

    # Library names are different on Windows.
    # NOTE: This mapping used to be used as part of the function discovery
    # process, and will likely need to be restored.
    libnames = {
        'avcodec':'avcodec-56',
        'avformat':'avformat-56',
        'avutil':'avutil-54',
    }

    dlls = [
        'avcodec-56.dll',
        'avdevice-56.dll',
        'avfilter-5.dll',
        'avformat-56.dll',
        'avutil-54.dll',
        'libgcc_s_dw2-1.dll',
        'libwinpthread-1.dll',
        'postproc-53.dll',
        'swresample-1.dll',
        'swscale-3.dll',
    ]

    # Ensure the libraries exist for proper wheel packaging
    for dll in dlls:
        if not os.path.isfile(os.path.join('av', dll)):
            print("missing %s; please find and copy it into the 'av' directory" % dll)

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
    cc = _new_compiler()
    if kwargs.pop('silent', True):
        cc.spawn = _CCompiler_spawn_silent
    return cc


def compile_check(code, name, includes=None, include_dirs=None, libraries=None,
    library_dirs=None, link=True
):
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

    with open(source_path, 'w') as fh:
        for include in includes or ():
            fh.write('#include "%s"\n' % include)
        fh.write('main(int argc, char **argv)\n{ %s; }\n' % code)

    cc = new_compiler()

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

    user_options = []
    def initialize_options(self):
        pass
    def finalize_options(self):
        pass

    def run(self):

        errors = []

        # Get the config for the libraries that we require.
        for name in 'libavformat', 'libavcodec', 'libavdevice', 'libavutil', 'libswscale':
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

    user_options = []

    def initialize_options(self):
        self.build_temp = None

    def finalize_options(self):
        self.set_undefined_options('build',
            ('build_temp', 'build_temp'),
        )

    def run(self):

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

        # Check for some specific functions.
        cc = new_compiler()
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
                libraries=extension_extra['libraries'],
                library_dirs=extension_extra['library_dirs']
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
                include_dirs=extension_extra['include_dirs'],
                link=False
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
                new_ext = cythonize(ext,
                    # Keep these in sync with the Makefile cythonize target.
                    compiler_directives=dict(
                        c_string_type='str',
                        c_string_encoding='ascii',
                    ),
                    build_dir='src',
                    include_path=ext.include_dirs,
                )[0]
                ext.sources = new_ext.sources



class BuildExtCommand(build_ext):

    def run(self):

        self.run_command('config')
        self.run_command('reflect')

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
        'config': ConfigCommand,
        'cythonize': CythonizeCommand,
        'doctor': DoctorCommand,
        'reflect': ReflectCommand,
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

)
