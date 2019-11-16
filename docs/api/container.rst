
Containers
==========


Generic
-------

.. currentmodule:: av.container

.. automodule:: av.container

.. autoclass:: Container

    .. attribute:: options
    .. attribute:: container_options
    .. attribute:: stream_options
    .. attribute:: metadata_encoding
    .. attribute:: metadata_errors
    .. attribute:: open_timeout
    .. attribute:: read_timeout


Flags
~~~~~

.. seealso:: Interpreting :ref:`flags`.

.. autoattribute:: Container.flags

.. flagtable::
    :cls: av.container.core:Container
    :enum: av.container.core:ContainerContextFlags


Input Containers
----------------

.. autoclass:: InputContainer
    :members:


Output Containers
-----------------

.. autoclass:: OutputContainer
    :members:


Formats
-------

.. currentmodule:: av.format

.. automodule:: av.format

    .. autoclass:: ContainerFormat
        :members:
