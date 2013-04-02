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
            **ext_extra
        ))


setup(

    name='av',
    version='0.1',
    description='Pythonic bindings for libav.',
    
    author="Mike Boers",
    author_email="pyav@mikeboers.com",
    
    url="https://github.com/mikeboers/PyAV",
    
    ext_modules=ext_modules,

)