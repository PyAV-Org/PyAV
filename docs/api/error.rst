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
which we do our best to translate to the builtin exceptions as defined by
`PEP 3151 <https://www.python.org/dev/peps/pep-3151/#new-exception-classes>`_
(and fall back onto ``OSError`` if using Python < 3.3).


.. _error_types:

Error Type Enumerations
-----------------------

We provide :class:`av.error.ErrorType` as an enumeration of the various FFmpeg errors.
To mimick the stdlib ``errno`` module, all enumeration values are availible in
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

PyAV provides an exception type for each FFmpeg error. All such exceptions
inherit from a base :class:`av.AVError`, and they are availible on the top-level
``av`` package, e.g.::

    try:
        do_something()
    except av.FilterNotFoundError:
        handle_error()


.. autoclass:: av.AVError

.. note:: Not all exceptions raised by PyAV will be ``AVError``, just the
    ones internal to the operation of FFmpeg. FFmpeg may raise "normal"
    ``OSError`` derivatives, e.g. ``FileNotFoundError``. See :ref:`error_behaviour`.


Mapping Codes and Classes
-------------------------

Here is how the classes line up with the error codes/enumerations:

.. include:: ../error_table.rst

