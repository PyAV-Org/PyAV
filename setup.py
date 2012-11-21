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

ffmpeg = Extension(
    'ffmpeg',
    sources=['ffmpegmodule.c'],
    **pkg_config('libavformat', 'libavcodec', 'libswscale', 'libavutil')
)

setup(
    name='FFMPy',
    version='1.0',
    description='This is a demo package',
    ext_modules=[ffmpeg],
)