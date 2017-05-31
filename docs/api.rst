API Reference
^^^^^^^^^^^^^

General
===============

.. warning:: This is far from complete, and is mostly an automatic dump of the API.


Global
------

.. autofunction:: av.open


Containers
----------

.. automodule:: av.container

    .. autoclass:: Container
        :members:
    .. autoclass:: InputContainer
        :members:
    .. autoclass:: OutputContainer
        :members:

.. automodule:: av.container.streams

    .. autoclass:: StreamContainer
        :members:
        
.. automodule:: av.format

    .. autoclass:: ContainerFormat
        :members:

Streams
-------

.. automodule:: av.stream

    .. autoclass:: Stream
        :members:

Packets
-------

.. automodule:: av.packet

    .. autoclass:: Packet
        :members:

Codecs
------

.. automodule:: av.codec.codec

    .. autoclass:: Codec
        :members:

.. automodule:: av.codec.context

    .. autoclass:: CodecContext
        :members:


Frames
------

.. automodule:: av.frame

    .. autoclass:: Frame
        :members:

Planes
------

.. automodule:: av.plane

    .. autoclass:: Plane
        :members:


Video
===============

Video Streams
-------------

.. automodule:: av.video.stream

    .. autoclass:: VideoStream
        :members:

Video Codecs
-------------

.. automodule:: av.video.codeccontext

    .. autoclass:: VideoCodecContext
        :members:

Video Formats
-------------

.. automodule:: av.video.format

    .. autoclass:: VideoFormat
        :members:

    .. autoclass:: VideoFormatComponent
        :members:

Video Frames
------------

.. automodule:: av.video.frame

    .. autoclass:: VideoFrame
        :members:
        :exclude-members: width, height, format

        .. autoattribute:: width
        .. autoattribute:: height
        .. autoattribute:: format


Video Planes
-------------

.. automodule:: av.video.plane

    .. autoclass:: VideoPlane
        :members:


Audio
=====

Audio Streams
-------------

.. automodule:: av.audio.stream

    .. autoclass:: AudioStream
        :members:

Audio Context
-------------

.. automodule:: av.audio.codeccontext

    .. autoclass:: AudioCodecContext
        :members:

Audio Formats
-------------

.. automodule:: av.audio.format

    .. autoclass:: AudioFormat
        :members:

Audio Layouts
-------------

.. automodule:: av.audio.layout

    .. autoclass:: AudioLayout
        :members:

Audio Frames
------------

.. automodule:: av.audio.frame

    .. autoclass:: AudioFrame
        :members:

Audio FIFOs
-----------

.. automodule:: av.audio.fifo

    .. autoclass:: AudioFifo
        :members:
        :exclude-members: write, read, read_many

        .. automethod:: write
        .. automethod:: read
        .. automethod:: read_many

Audio Resamplers
----------------

.. automodule:: av.audio.resampler

    .. autoclass:: AudioResampler
        :members:
        :exclude-members: resample

        .. automethod:: resample



Subtitles
===========

.. automodule:: av.subtitles.stream

    .. autoclass:: SubtitleStream
        :members:

.. automodule:: av.subtitles.subtitle

    .. autoclass:: SubtitleSet
        :members:
        
    .. autoclass:: Subtitle
        :members:

    .. autoclass:: BitmapSubtitle
        :members:

    .. autoclass:: BitmapSubtitlePlane
        :members:

    .. autoclass:: TextSubtitle
        :members:

    .. autoclass:: AssSubtitle
        :members:


Utilities
=========

Logging
-------

.. automodule:: av.logging
    :members:

Other
-----

.. automodule:: av.utils
    :members:

    .. autoclass:: AVError


