from distutils.core import setup, Extension
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


setup(
    name='PyAV',
    version='0.1',
    description='Pythonic bindings for libav.',
    ext_modules=[
        Extension(
            'av.tutorial',
            sources=['build/av/tutorial.c'],
            **pkg_config('libavformat', 'libavcodec', 'libswscale', 'libavutil')
        ),
    ],
)