Caveats
=======

.. _authority_of_docs:

Authority of Documentation
--------------------------

FFmpeg_ is extremely complex, and the PyAV developers have not been successful in making it 100% clear to themselves in all aspects. Our understanding of how it works and how to work with it is via reading the docs, digging through the source, performing experiments, and hearing from users where PyAV isn't doing the right thing.

Only where this documentation is about the mechanics of PyAV can it be considered authoritative. Anywhere that we discuss something that is about the underlying FFmpeg libraries comes with the caveat that we can not be 100% sure on it. It is, unfortunately, often on the user to understand and deal with edge cases. We encourage you to bring them to our attention via GitHub_ so that we can try to make PyAV deal with it.


Unsupported Features
--------------------

Our goal is to provide all of the features that make sense for the contexts that PyAV would be used in. If there is something missing, please reach out on GitHub_ or open a feature request (or even better a pull request). Your request will be more likely to be addressed if you can point to the relevant `FFmpeg API documentation <https://ffmpeg.org/doxygen/trunk/index.html>`__.


Sub-Interpreters
----------------

Since we rely upon C callbacks in a few locations, PyAV is not fully compatible with sub-interpreters. Users have experienced lockups in WSGI web applications, for example.

This is due to the ``PyGILState_Ensure`` calls made by Cython in a C callback from FFmpeg. If this is called in a thread that was not started by Python, it is very likely to break. There is no current instrumentation to detect such events.

The two main features that can cause lockups are:

1. Python IO (passing a file-like object to ``av.open``). While this is in theory possible, so far it seems like the callbacks are made in the calling thread, and so are safe.

2. Logging. If you have logging enabled (disabled by default), those log messages could cause lockups when using threads.


.. _garbage_collection:

Garbage Collection
------------------

PyAV currently has a number of reference cycles that make it more difficult for the garbage collector than we would like. In some circumstances (usually tight loops involving opening many containers), a :class:`.Container` will not auto-close until many a few thousand have built-up.

Until we resolve this issue, you should explicitly call :meth:`.Container.close` or use the container as a context manager::

    with av.open(path) as container:
        # Do stuff with it.


.. _FFmpeg: https://ffmpeg.org/
.. _GitHub: https://github.com/PyAV-Org/PyAV
