
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

.. attribute:: av.container.Container.flags

.. class:: av.container.Flags

    Wraps :ffmpeg:`AVFormatContext.flags`.

    .. enumtable:: av.container.core:Flags
        :class: av.container.core:Container


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

.. autoattribute:: ContainerFormat.name
.. autoattribute:: ContainerFormat.long_name

.. autoattribute:: ContainerFormat.options
.. autoattribute:: ContainerFormat.input
.. autoattribute:: ContainerFormat.output
.. autoattribute:: ContainerFormat.is_input
.. autoattribute:: ContainerFormat.is_output
.. autoattribute:: ContainerFormat.extensions

Flags
~~~~~

.. autoattribute:: ContainerFormat.flags

.. autoclass:: av.format.Flags

    .. enumtable:: av.format.Flags
        :class: av.format.ContainerFormat

