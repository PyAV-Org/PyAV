Caveats
=======

Sub-Interpeters
---------------

Since we rely upon C callbacks in a few locations, PyAV is not fully compatible with sub-interpreters. Users have experienced lockups in WSGI web applications, for example.

This is due to the ``PyGILState_Ensure`` calls made by Cython in a C callback from FFmpeg. If this is called in a thread that was not started by Python, it is very likely to break. There is no current instrumentation to detect such events.

The two main features that are able to cause lockups are:

1. Python IO (passing a file-like object to ``av.open``). While this is in theory possible, so far it seems like the callbacks are made in the calling thread, and so are safe.

2. Logging. As soon as you en/decode with threads you are highly likely to get log messages issues from threads started by FFmpeg, and you will get lockups. See :ref:`disable_logging`.
