Caveats
=======

.. _authority_of_docs:

Authority of Documentation
--------------------------

FFmpeg is extremely complex, and the PyAV developers have not been successful in making it 100% clear to themselves in all aspects. Our understanding of how it works and how to work with it is via reading the docs, digging through the source, perfoming experiments, and hearing from users where PyAV isn't doing the right thing.

Only where this documentation is about the mechanics of PyAV can it be considered authoritative. Anywhere that we discuss something that is actually about the underlying FFmpeg libraries comes with the caveat that we can not always be 100% on it.

It is, unfortunately, often on the user the understand and deal with the edge cases. We encourage you to bring them to our attension via GitHub_ so that we can try to make PyAV deal with it, but we can't always make it work.

.. _GitHub: https://github.com/PyAv-Org/PyAV/issues


Sub-Interpeters
---------------

Since we rely upon C callbacks in a few locations, PyAV is not fully compatible with sub-interpreters. Users have experienced lockups in WSGI web applications, for example.

This is due to the ``PyGILState_Ensure`` calls made by Cython in a C callback from FFmpeg. If this is called in a thread that was not started by Python, it is very likely to break. There is no current instrumentation to detect such events.

The two main features that are able to cause lockups are:

1. Python IO (passing a file-like object to ``av.open``). While this is in theory possible, so far it seems like the callbacks are made in the calling thread, and so are safe.

2. Logging. As soon as you en/decode with threads you are highly likely to get log messages issues from threads started by FFmpeg, and you will get lockups. See :ref:`disable_logging`.


.. _garbage_collection:

Garbage Collection
------------------

PyAV currently has a number of reference cycles that make it more difficult for the garbage collector than we would like. In some circumstances (usually tight loops involving opening many containers), a :class:`.Container` will not auto-close until many a few thousand have built-up.

Until we resolve this issue, you should explicitly call :meth:`.Container.close` or use the container as a context manager::

    with av.open(path) as fh:
        # Do stuff with it.
