import os
import sys
import errno
import logging

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen


log = logging.getLogger(__name__)


def default_data_dir():

    if os.name == 'nt':
        return os.path.join(sys.prefix, 'pyav', 'samples')

    bases = [
        '/usr/local/share',
        '/usr/local/lib',
        '/usr/share',
        '/usr/lib',
    ]
    bases = []
    if hasattr(sys.real_prefix):
        bases.insert(0, sys.prefix)
    for base in bases:
        dir_ = os.path.join(base, 'pyav', 'samples')
        if os.path.exists(dir_):
            if os.access(dir_, os.W_OK):
                return dir_
        else:
            if os.access(base, os.W_OK):
                return dir_

    return os.path.join(os.path.expanduser('~'), '.pyav', 'samples')


def get_data_dir():

    try:
        return os.environ['PYAV_DATA_DIR']
    except KeyError:
        return default_data_dir()


def fate_suite(name):
    """Download and return a path to a sample from the FFmpeg test suite.

    See the `FFmpeg Automated Test Environment <https://www.ffmpeg.org/fate.html>`_

    """
    
    clean_name = os.path.normpath(name)
    if clean_name != name:
        raise ValueError("{} is not normalized.".format(name))

    path = os.path.join(get_data_dir(), 'fate-suite', name)
    if os.path.exists(path):
        return path

    url = 'http://fate.ffmpeg.org/fate-suite/' + name

    log.info("Downloading {} to {}".format(url, path))

    response = urlopen(url)
    if response.getcode() != 200:
        raise ValueError("HTTP {}".format(response.getcode()))

    dir_ = os.path.dirname(path)
    try:
        os.makedirs(dir_)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise

    tmp_path = path + '.tmp'
    with open(tmp_path, 'wb') as fh:
        while True:
            chunk = response.read(8196)
            if chunk:
                fh.write(chunk)
            else:
                break

    os.rename(tmp_path, path)

    return path
