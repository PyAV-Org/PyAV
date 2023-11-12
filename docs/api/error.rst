Errors
======

.. currentmodule:: av.error

.. _error_behaviour:

General Behaviour
-----------------

When PyAV encounters an FFmpeg error, it raises an appropriate exception.

FFmpeg has a couple dozen of its own error types which we represent via
:ref:`error_classes` and at a lower level via :ref:`error_types`.

FFmpeg will also return more typical errors such as ``ENOENT`` or ``EAGAIN``,
which we do our best to translate to extensions of the builtin exceptions
as defined by
`PEP 3151 <https://www.python.org/dev/peps/pep-3151/#new-exception-classes>`_
(and fall back onto ``OSError`` if using Python < 3.3).


.. _error_types:

Error Type Enumerations
-----------------------

We provide :class:`av.error.ErrorType` as an enumeration of the various FFmpeg errors.
To mimick the stdlib ``errno`` module, all enumeration values are available in
the ``av.error`` module, e.g.::

    try:
        do_something()
    except OSError as e:
        if e.errno != av.error.FILTER_NOT_FOUND:
            raise
        handle_error()


.. autoclass:: av.error.ErrorType


.. _error_classes:

Error Exception Classes
-----------------------

PyAV raises the typical builtin exceptions within its own codebase, but things
get a little more complex when it comes to translating FFmpeg errors.

There are two competing ideas that have influenced the final design:

1. We want every exception that originates within FFmpeg to inherit from a common
   :class:`.FFmpegError` exception;

2. We want to use the builtin exceptions whenever possible.

As such, PyAV effectivly shadows as much of the builtin exception heirarchy as
it requires, extending from both the builtins and from :class:`FFmpegError`.

Therefore, an argument error within FFmpeg will raise a ``av.error.ValueError``, which
can be caught via either :class:`FFmpegError` or ``ValueError``. All of these
exceptions expose the typical ``errno`` and ``strerror`` attributes (even
``ValueError`` which doesn't typically), as well as some PyAV extensions such
as :attr:`FFmpegError.log`.

All of these exceptions are available on the top-level ``av`` package, e.g.::

    try:
        do_something()
    except av.FilterNotFoundError:
        handle_error()


.. autoclass:: av.FFmpegError


Mapping Codes and Classes
-------------------------

Here is how the classes line up with the error codes/enumerations:

.. include:: ../_build/rst/api/error_table.rst


