from unittest import TestCase
import doctest
import os
import re
import sys

import av


def fix_doctests(suite):
    for case in suite._tests:

        # Add some more flags.
        case._dt_optionflags = (
            (case._dt_optionflags or 0) |
            doctest.IGNORE_EXCEPTION_DETAIL |
            doctest.ELLIPSIS |
            doctest.NORMALIZE_WHITESPACE
        )

        if sys.version_info[0] >= 3:
            continue
        
        # Remove b prefix from strings.
        for example in case._dt_test.examples:
            if example.want.startswith("b'"):
                example.want = example.want[1:]


def register_doctests(mod):

    if isinstance(mod, basestring):
        mod = __import__(mod, fromlist=['.'])
    try:
        suite = doctest.DocTestSuite(mod)
    except ValueError:
        return

    fix_doctests(suite)

    cls_name = 'Test' + ''.join(x.title() for x in mod.__name__.split('.'))
    cls = type(cls_name, (TestCase, ), {})

    for test in suite._tests:
        func = lambda self: test.runTest()
        name = str('test_' + re.sub('[^a-zA-Z0-9]+', '_', test.id()).strip('_'))
        func.__name__ = name
        setattr(cls, name, func)

    globals()[cls_name] = cls


root = av.__path__[0]
for dir_name, dir_names, file_names in os.walk(root):
    for file_name in file_names:
        base, ext = os.path.splitext(file_name)
        if base in ('__init__', ):
            continue
        if ext not in ('.so', '.py'):
            continue
        mod_name = 'av.' + os.path.relpath(os.path.join(dir_name, base), root).replace('/', '.')
        register_doctests(mod_name)

