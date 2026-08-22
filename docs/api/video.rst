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

.. autoclass:: CudaContext
    :members:

.. autoclass:: VideoFrame

    A single video frame.

    :param int width: The width of the frame.
    :param int height: The height of the frame.
    :param format: The format of the frame.
    :type  format: :class:`VideoFormat` or ``str``.

    >>> frame = VideoFrame(1920, 1080, 'rgb24')

Structural
~~~~~~~~~~

.. autoattribute:: VideoFrame.width
.. autoattribute:: VideoFrame.height
.. attribute:: VideoFrame.format

    The :class:`.VideoFormat` of the frame.

.. autoattribute:: VideoFrame.planes

Types
~~~~~

.. autoattribute:: VideoFrame.key_frame
.. autoattribute:: VideoFrame.interlaced_frame
.. autoattribute:: VideoFrame.pict_type

.. autoclass:: av.video.frame.PictureType

    Wraps ``AVPictureType`` (``AV_PICTURE_TYPE_*``).

    .. enumtable:: av.video.frame.PictureType


Colors
~~~~~~

These describe how to interpret the frame's samples. They are FFmpeg's raw
integer values, and each is named by an enum under :ref:`video_enums`. A
decoder fills them in from the stream; an encoder passes them through to the
container. Setting one relabels the frame, it does not convert the pixels --
see :meth:`VideoFrame.reformat` for that.

.. autoattribute:: VideoFrame.colorspace
.. autoattribute:: VideoFrame.color_range
.. autoattribute:: VideoFrame.color_trc
.. autoattribute:: VideoFrame.color_primaries
.. autoattribute:: VideoFrame.chroma_location

The matching :class:`.VideoCodecContext` attributes carry the same values for a
whole stream. FFmpeg spells the chroma one ``chroma_location`` on a frame and
``chroma_sample_location`` on a codec context, and PyAV mirrors each C field
name, so :attr:`.VideoCodecContext.chroma_sample_location` is the codec context
spelling of :attr:`VideoFrame.chroma_location`.


Conversions
~~~~~~~~~~~

.. automethod:: VideoFrame.reformat

.. automethod:: VideoFrame.to_rgb
.. automethod:: VideoFrame.to_image
.. automethod:: VideoFrame.to_ndarray

.. automethod:: VideoFrame.from_image
.. automethod:: VideoFrame.from_ndarray
.. automethod:: VideoFrame.from_dlpack



Video Planes
-------------

.. automodule:: av.video.plane

    .. autoclass:: VideoPlane
        :members:


Video Reformatters
------------------

.. automodule:: av.video.reformatter

    .. autoclass:: VideoReformatter

        .. automethod:: reformat

.. _video_enums:

Enums
~~~~~

.. autoclass:: av.video.reformatter.Interpolation

    Wraps the ``SWS_*`` flags.

    .. enumtable:: av.video.reformatter.Interpolation

.. autoclass:: av.video.reformatter.Colorspace

    Wraps the ``SWS_CS_*`` flags. There is a bit of overlap in
    these names which comes from FFmpeg and backwards compatibility.

    .. enumtable:: av.video.reformatter.Colorspace

.. autoclass:: av.video.reformatter.ColorRange

    Wraps the ``AVCOL_RANGE_*`` flags.

    .. enumtable:: av.video.reformatter.ColorRange

.. autoclass:: av.video.reformatter.ColorTrc

    Wraps the ``AVCOL_TRC_*`` flags.

    .. enumtable:: av.video.reformatter.ColorTrc

.. autoclass:: av.video.reformatter.ColorPrimaries

    Wraps the ``AVCOL_PRI_*`` flags.

    .. enumtable:: av.video.reformatter.ColorPrimaries

.. autoclass:: av.video.reformatter.ChromaLocation

    Wraps the ``AVCHROMA_LOC_*`` flags.

    .. enumtable:: av.video.reformatter.ChromaLocation
