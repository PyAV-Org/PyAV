
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

.. class:: av.container.Flags

    :class:`av.enum.EnumType` set for :ffmpeg:`AVFormatContext.flags`.

.. attribute:: av.container.Container.flags

    :class:`av.enum.EnumFlag` set for :ffmpeg:`AVFormatContext.flags`.

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
        :members:

.. autoclass:: av.format.Flags
.. enumtable:: av.format.Flags

