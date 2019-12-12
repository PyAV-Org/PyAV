Video
=====

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
        :exclude-members: width, height, format, to_nd_array

        .. autoattribute:: width
        .. autoattribute:: height
        .. autoattribute:: format

.. autoclass:: av.video.frame.PictureType

    The ``AVPictureType`` enum (``AV_PICTURE_TYPE_*``) in FFmpeg.

.. enumtable:: av.video.frame.PictureType

Video Planes
-------------

.. automodule:: av.video.plane

    .. autoclass:: VideoPlane
        :members:


Video Reformatters
------------------

.. automodule:: av.video.reformatter

    .. autoclass:: VideoReformatter
        :members:

.. autoclass:: av.video.reformatter.Interpolation

    The various ``SWS_*`` flags in FFmpeg.

.. enumtable:: av.video.reformatter.Interpolation

.. autoclass:: av.video.reformatter.Colorspace

    The various ``SWS_CS_*`` flags in FFmpeg. There is a bit of overlap in
    these names which comes from FFmpeg and backards compatibility.

.. enumtable:: av.video.reformatter.Colorspace

