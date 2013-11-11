General
===============

.. automodule:: av.container

    .. autoclass:: Container
        :members:
    .. autoclass:: InputContainer
        :members:
    .. autoclass:: OutputContainer
        :members:

.. automodule:: av.format

    .. autoclass:: ContainerFormat
        :members:

.. automodule:: av.stream

    .. autoclass:: Stream
        :members:

.. automodule:: av.packet

    .. autoclass:: Packet
        :members:

.. automodule:: av.frame

    .. autoclass:: Frame
        :members:

.. automodule:: av.plane

    .. autoclass:: Plane
        :members:


Video
=============

.. automodule:: av.video.stream

    .. autoclass:: VideoStream
        :members:

.. automodule:: av.video.format

    .. autoclass:: VideoFormat
        :members:

.. automodule:: av.video.frame

    .. autoclass:: VideoFrame
        :members:
        :exclude-members: width, height, format

        .. autoattribute:: width
        .. autoattribute:: height
        .. autoattribute:: format



Audio
=============

.. automodule:: av.audio.stream

    .. autoclass:: AudioStream
        :members:

.. automodule:: av.audio.format

    .. autoclass:: AudioFormat
        :members:

.. automodule:: av.audio.layout

    .. autoclass:: AudioLayout
        :members:

.. automodule:: av.audio.frame

    .. autoclass:: AudioFrame
        :members:

.. automodule:: av.audio.fifo

    .. autoclass:: AudioFifo
        :members:

.. automodule:: av.audio.resampler

    .. autoclass:: AudioResampler
        :members:



Subtitles
===========

.. automodule:: av.subtitles.stream

    .. autoclass:: SubtitleStream
        :members:

.. automodule:: av.subtitles.subtitle

    .. autoclass:: Subtitle
        :members:
        
    .. autoclass:: SubtitleRect
        :members:

