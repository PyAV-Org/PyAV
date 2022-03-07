Caveats
=======

.. _authority_of_docs:

Authority of Documentation
--------------------------

FFmpeg_ is extremely complex, and the PyAV developers have not been successful in making it 100% clear to themselves in all aspects. Our understanding of how it works and how to work with it is via reading the docs, digging through the source, perfoming experiments, and hearing from users where PyAV isn't doing the right thing.

Only where this documentation is about the mechanics of PyAV can it be considered authoritative. Anywhere that we discuss something that is actually about the underlying FFmpeg libraries comes with the caveat that we can not always be 100% on it.

It is, unfortunately, often on the user the understand and deal with the edge cases. We encourage you to bring them to our attention via GitHub_ so that we can try to make PyAV deal with it, but we can't always make it work.


Unsupported Features
--------------------

Our goal is to provide all of the features that make sense for the contexts that PyAV would be used in. If there is something missing, please reach out on Gitter_ or open a feature request on GitHub_ (or even better a pull request). Your request will be more likely to be addressed if you can point to the relevant `FFmpeg API documentation <https://ffmpeg.org/doxygen/trunk/index.html>`__.

There are some features we may elect to not implement because we don't believe they fit the PyAV ethos. The only one that we've encountered so far is hardware decoding. The `FFmpeg man page <https://ffmpeg.org/ffmpeg.html>`__ discusses the drawback of ``-hwaccel``:

    Note that most acceleration methods are intended for playback and will not be faster than software decoding on modern CPUs. Additionally, ``ffmpeg`` will usually need to copy the decoded frames from the GPU memory into the system memory, resulting in further performance loss.

Since PyAV is not expected to be used in a high performance playback loop, we do not find the added code complexity worth the benefits of supporting this feature.


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


.. _FFmpeg: https://ffmpeg.org/
.. _Gitter: https://gitter.im/PyAV-Org
.. _GitHub: https://github.com/PyAV-Org/pyav
