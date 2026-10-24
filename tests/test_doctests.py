import doctest
import pkgutil
import re
import types
from typing import Any
from unittest import TestCase

import av
import av.datasets

VIDEO_PATH = av.datasets.curated("pexels/time-lapse-video-of-night-sky-857195.mp4")


class DocTestFinder(doctest.DocTestFinder):
    def find(self, *args: Any, **kwargs: Any) -> list[doctest.DocTest]:
        tests = super().find(*args, **kwargs)
        for test in tests:
            for example in test.examples:
                # Remove b prefix from strings.
                if example.want.startswith("b'"):
                    example.want = example.want[1:]
        return tests


def register_doctests(mod: str | types.ModuleType) -> None:
    if isinstance(mod, str):
        mod = __import__(mod, fromlist=[""])

    try:
        suite = doctest.DocTestSuite(
            mod,
            extraglobs={"av": av, "video_path": VIDEO_PATH},
            test_finder=DocTestFinder(),
            optionflags=doctest.IGNORE_EXCEPTION_DETAIL
            | doctest.ELLIPSIS
            | doctest.NORMALIZE_WHITESPACE,
        )
    except ValueError:
        return

    cls_name = "Test" + "".join(x.title() for x in mod.__name__.split("."))
    cls = type(cls_name, (TestCase,), {})

    for test in suite:
        assert isinstance(test, doctest.DocTestCase)

        def func(self: TestCase) -> None:
            return test.runTest()

        name = str("test_" + re.sub("[^a-zA-Z0-9]+", "_", test.id()).strip("_"))
        func.__name__ = name
        setattr(cls, name, func)

    globals()[cls_name] = cls


for importer, mod_name, ispkg in pkgutil.walk_packages(
    path=av.__path__, prefix=av.__name__ + ".", onerror=lambda x: None
):
    register_doctests(mod_name)
