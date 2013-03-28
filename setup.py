from distutils.core import setup, Extension
import os
import subprocess


if not os.path.exists('config.py'):
    subprocess.call(['./configure'])
execfile("config.py")

ext_extra = {
    'include_dirs': ['headers'],
}

for chunk in autoconf_flags.strip().split():
    if chunk.startswith('-I'):
        ext_extra.setdefault('include_dirs', []).append(chunk[2:])
    elif chunk.startswith('-L'):
        ext_extra.setdefault('library_dirs', []).append(chunk[2:])
    elif chunk.startswith('-l'):
        ext_extra.setdefault('libraries', []).append(chunk[2:])
    elif chunk.startswith('-D'):
        name = chunk[2:].split('=')[0]
        if name.startswith('HAVE'):
            ext_extra.setdefault('define_macros', []).append((name, None))


# Construct the modules that we find in the "build/av" directory.
ext_basenames = os.listdir(os.path.abspath(os.path.join(__file__, '..', 'build', 'av')))
ext_names = ['av.' + x[:-2] for x in ext_basenames]
ext_sources = ['build/av/' + x for x in ext_basenames]
ext_modules = [Extension(
    name,
    sources=[source],
    **ext_extra
) for name, source in zip(ext_names, ext_sources)]


setup(

    name='av',
    version='0.1',
    description='Pythonic bindings for libav.',
    
    author="Mike Boers",
    author_email="pyav@mikeboers.com",
    
    url="https://github.com/mikeboers/PyAV",
    
    ext_modules=ext_modules,

)