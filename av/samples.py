import os
import sys
import errno
import logging

try:
    from urllib.request import urlopen
except ImportError:
    from urllib2 import urlopen


log = logging.getLogger(__name__)


def iter_data_dirs(check_writable=False):

    try:
        yield os.environ['PYAV_DATA_DIR']
    except KeyError:
        pass

    if os.name == 'nt':
        yield os.path.join(sys.prefix, 'pyav', 'samples')
        return

    bases = [
        '/usr/local/share',
        '/usr/local/lib',
        '/usr/share',
        '/usr/lib',
    ]

    # Prefer the local virtualenv.
    if hasattr(sys, 'real_prefix'):
        bases.insert(0, sys.prefix)

    for base in bases:
        dir_ = os.path.join(base, 'pyav', 'samples')
        if check_writable:
            if os.path.exists(dir_):
                if not os.access(dir_, os.W_OK):
                    continue
            else:
                if not os.access(base, os.W_OK):
                    continue
        yield dir_

    yield os.path.join(os.path.expanduser('~'), '.pyav', 'samples')


def fate_suite(name):
    """Download and return a path to a sample from the FFmpeg test suite.
    
    The samples are stored under `pyav/samples/fate-suite` in the path indicated
    by :envvar:`PYAV_DATA_DIR`, or the first that is writeable of:

    - the current virtualenv
    - ``/usr/local/share``
    - ``/usr/local/lib``
    - ``/usr/share``
    - ``/usr/lib``
    - the user's home

    See the `FFmpeg Automated Test Environment <https://www.ffmpeg.org/fate.html>`_

    """

    clean_name = os.path.normpath(name)
    if clean_name != name:
        raise ValueError("{} is not normalized.".format(name))

    for dir_ in iter_data_dirs():
        path = os.path.join(dir_, 'fate-suite', name)
        if os.path.exists(path):
            return path

    dir_ = next(iter_data_dirs(True))
    path = os.path.join(dir_, 'fate-suite', name)

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
