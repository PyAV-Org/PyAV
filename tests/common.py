from __future__ import annotations

import datetime
import errno
import functools
import os
import types
import typing
from typing import TYPE_CHECKING
from unittest import TestCase as _Base

import numpy as np

from av.datasets import fate as fate_suite

try:
    import PIL  # noqa

    has_pillow = True
except ImportError:
    has_pillow = False

if TYPE_CHECKING:
    from typing import Any, Callable, TypeVar

    from PIL.Image import Image

    T = TypeVar("T")


__all__ = ("fate_suite",)


is_windows = os.name == "nt"
skip_tests = frozenset(os.environ.get("PYAV_SKIP_TESTS", "").split(","))


def safe_makedirs(path: str) -> None:
    try:
        os.makedirs(path)
    except OSError as e:
        if e.errno != errno.EEXIST:
            raise


_start_time = datetime.datetime.now()


def _sandbox(timed: bool = False) -> str:
    root = os.path.abspath(os.path.join(__file__, "..", "..", "sandbox"))

    if timed:
        sandbox = os.path.join(root, _start_time.strftime("%Y%m%d-%H%M%S"))
    else:
        sandbox = root

    if not os.path.exists(sandbox):
        os.makedirs(sandbox)

    return sandbox


def asset(*args: str) -> str:
    adir = os.path.dirname(__file__)
    return os.path.abspath(os.path.join(adir, "assets", *args))


# Store all of the sample data here.
os.environ["PYAV_TESTDATA_DIR"] = asset()


def fate_png() -> str:
    return fate_suite("png1/55c99e750a5fd6_50314226.png")


def sandboxed(
    *args: str, makedirs: bool = True, sandbox: str | None = None, timed: bool = False
) -> str:
    path = os.path.join(_sandbox(timed) if sandbox is None else sandbox, *args)
    if makedirs:
        safe_makedirs(os.path.dirname(path))

    return path


# Decorator for running a test in the sandbox directory
def run_in_sandbox(func: Callable[..., T]) -> Callable[..., T]:
    @functools.wraps(func)
    def _inner(self: Any, *args: Any, **kwargs: Any) -> T:
        current_dir = os.getcwd()
        try:
            os.chdir(self.sandbox)
            return func(self, *args, **kwargs)
        finally:
            os.chdir(current_dir)

    return _inner


def assertNdarraysEqual(a: np.ndarray, b: np.ndarray) -> None:
    assert a.shape == b.shape

    comparison = a == b
    if not comparison.all():
        it = np.nditer(comparison, flags=["multi_index"])
        msg = ""
        for equal in it:
            if not equal:
                msg += "- arrays differ at index {}; {} {}\n".format(
                    it.multi_index,
                    a[it.multi_index],
                    b[it.multi_index],
                )
        assert False, f"ndarrays contents differ\n{msg}"


@typing.no_type_check
def assertImagesAlmostEqual(a: Image, b: Image, epsilon: float = 0.1) -> None:
    import PIL.ImageFilter as ImageFilter

    assert a.size == b.size
    a = a.filter(ImageFilter.BLUR).getdata()
    b = b.filter(ImageFilter.BLUR).getdata()
    for i, ax, bx in zip(range(len(a)), a, b):
        diff = sum(abs(ac / 256 - bc / 256) for ac, bc in zip(ax, bx)) / 3
        assert diff < epsilon, f"images differed by {diff} at index {i}; {ax} {bx}"


class TestCase(_Base):
    @classmethod
    def _sandbox(cls, timed: bool = True) -> str:
        path = os.path.join(_sandbox(timed=timed), cls.__name__)
        safe_makedirs(path)
        return path

    @property
    def sandbox(self) -> str:
        return self._sandbox(timed=True)

    def sandboxed(
        self,
        *args: str,
        makedirs: bool = True,
        timed: bool = True,
        sandbox: str | None = None,
    ) -> str:
        if sandbox is None:
            return sandboxed(
                *args, makedirs=makedirs, timed=timed, sandbox=self.sandbox
            )
        else:
            return sandboxed(*args, makedirs=makedirs, timed=timed, sandbox=sandbox)
