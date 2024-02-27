import doctest
import pkgutil
import re
from unittest import TestCase

import av
import av.datasets


def fix_doctests(suite):
    for case in suite._tests:
        # Add some more flags.
        case._dt_optionflags = (
            (case._dt_optionflags or 0)
            | doctest.IGNORE_EXCEPTION_DETAIL
            | doctest.ELLIPSIS
            | doctest.NORMALIZE_WHITESPACE
        )

        case._dt_test.globs["av"] = av
        case._dt_test.globs["video_path"] = av.datasets.curated(
            "pexels/time-lapse-video-of-night-sky-857195.mp4"
        )

        for example in case._dt_test.examples:
            # Remove b prefix from strings.
            if example.want.startswith("b'"):
                example.want = example.want[1:]


def register_doctests(mod):
    if isinstance(mod, str):
        mod = __import__(mod, fromlist=[""])

    try:
        suite = doctest.DocTestSuite(mod)
    except ValueError:
        return

    fix_doctests(suite)

    cls_name = "Test" + "".join(x.title() for x in mod.__name__.split("."))
    cls = type(cls_name, (TestCase,), {})

    for test in suite._tests:

        def func(self):
            return test.runTest()

        name = str("test_" + re.sub("[^a-zA-Z0-9]+", "_", test.id()).strip("_"))
        func.__name__ = name
        setattr(cls, name, func)

    globals()[cls_name] = cls


for importer, mod_name, ispkg in pkgutil.walk_packages(
    path=av.__path__, prefix=av.__name__ + ".", onerror=lambda x: None
):
    register_doctests(mod_name)
