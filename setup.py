from distutils.core import setup, Extension
import os
import subprocess


def pkg_config(*packages, **kw):
    
    flag_map = {
        '-I': 'include_dirs',
        '-L': 'library_dirs',
        '-l': 'libraries',
    }
    proc = subprocess.Popen(['pkg-config', '--libs', '--cflags'] + list(packages), stdout=subprocess.PIPE)
    out, err = proc.communicate()
    
    for token in out.strip().split():
        kw.setdefault(flag_map.get(token[:2]), []).append(token[2:])
    
    return kw


# Construct the modules that we find in the "build/av" directory.
ext_basenames = os.listdir(os.path.abspath(os.path.join(__file__, '..', 'build', 'av')))
ext_names = ['av.' + x[:-2] for x in ext_basenames]
ext_sources = ['build/av/' + x for x in ext_basenames]
ext_modules = [Extension(
    name,
    sources=[source],
    **pkg_config('libavformat', 'libavcodec', 'libswscale', 'libavutil')
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