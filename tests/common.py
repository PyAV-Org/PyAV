import datetime
import errno
import functools
import os
import types
from unittest import TestCase as _Base

from av.datasets import fate as fate_suite

try:
    import PIL.Image as Image
    import PIL.ImageFilter as ImageFilter
except ImportError:
    Image = ImageFilter = None


is_windows = os.name == "nt"
skip_tests = frozenset(os.environ.get("PYAV_SKIP_TESTS", "").split(","))


def makedirs(path):
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise


_start_time = datetime.datetime.now()


def _sandbox(timed=False):
    root = os.path.abspath(os.path.join(__file__, "..", "..", "sandbox"))

    sandbox = (
        os.path.join(
            root,
            _start_time.strftime("%Y%m%d-%H%M%S"),
        )
        if timed
        else root
    )
    if not os.path.exists(sandbox):
        os.makedirs(sandbox)
    return sandbox


def asset(*args):
    adir = os.path.dirname(__file__)
    return os.path.abspath(os.path.join(adir, "assets", *args))


# Store all of the sample data here.
os.environ["PYAV_TESTDATA_DIR"] = asset()


def fate_png():
    return fate_suite("png1/55c99e750a5fd6_50314226.png")


def sandboxed(*args, **kwargs):
    do_makedirs = kwargs.pop("makedirs", True)
    base = kwargs.pop("sandbox", None)
    timed = kwargs.pop("timed", False)
    if kwargs:
        raise TypeError("extra kwargs: %s" % ", ".join(sorted(kwargs)))
    path = os.path.join(_sandbox(timed=timed) if base is None else base, *args)
    if do_makedirs:
        makedirs(os.path.dirname(path))
    return path


# Decorator for running a test in the sandbox directory
def run_in_sandbox(func):
    @functools.wraps(func)
    def _inner(self, *args, **kwargs):
        current_dir = os.getcwd()
        try:
            os.chdir(self.sandbox)
            return func(self, *args, **kwargs)
        finally:
            os.chdir(current_dir)

    return _inner


class MethodLogger:
    def __init__(self, obj):
        self._obj = obj
        self._log = []

    def __getattr__(self, name):
        value = getattr(self._obj, name)
        if isinstance(
            value,
            (
                types.MethodType,
                types.FunctionType,
                types.BuiltinFunctionType,
                types.BuiltinMethodType,
            ),
        ):
            return functools.partial(self._method, name, value)
        else:
            self._log.append(("__getattr__", (name,), {}))
            return value

    def _method(self, name, meth, *args, **kwargs):
        self._log.append((name, args, kwargs))
        return meth(*args, **kwargs)

    def _filter(self, type_):
        return [log for log in self._log if log[0] == type_]


class TestCase(_Base):
    @classmethod
    def _sandbox(cls, timed=True):
        path = os.path.join(_sandbox(timed=timed), cls.__name__)
        makedirs(path)
        return path

    @property
    def sandbox(self):
        return self._sandbox(timed=True)

    def sandboxed(self, *args, **kwargs):
        kwargs.setdefault("sandbox", self.sandbox)
        kwargs.setdefault("timed", True)
        return sandboxed(*args, **kwargs)

    def assertNdarraysEqual(self, a, b):
        import numpy

        self.assertEqual(a.shape, b.shape)

        comparison = a == b
        if not comparison.all():
            it = numpy.nditer(comparison, flags=["multi_index"])
            msg = ""
            for equal in it:
                if not equal:
                    msg += "- arrays differ at index %s; %s %s\n" % (
                        it.multi_index,
                        a[it.multi_index],
                        b[it.multi_index],
                    )
            self.fail("ndarrays contents differ\n%s" % msg)

    def assertImagesAlmostEqual(self, a, b, epsilon=0.1, *args):
        self.assertEqual(a.size, b.size, "sizes dont match")
        a = a.filter(ImageFilter.BLUR).getdata()
        b = b.filter(ImageFilter.BLUR).getdata()
        for i, ax, bx in zip(range(len(a)), a, b):
            diff = sum(abs(ac / 256 - bc / 256) for ac, bc in zip(ax, bx)) / 3
            if diff > epsilon:
                self.fail(
                    "images differed by %s at index %d; %s %s" % (diff, i, ax, bx)
                )
