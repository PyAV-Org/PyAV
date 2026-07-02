
Codecs
======

Descriptors
-----------

.. currentmodule:: av.codec
.. automodule:: av.codec

.. autoclass:: Codec

.. automethod:: Codec.create

.. autoattribute:: Codec.is_decoder
.. autoattribute:: Codec.is_encoder

.. autoattribute:: Codec.name
.. autoattribute:: Codec.long_name
.. autoattribute:: Codec.type
.. autoattribute:: Codec.id

.. autoattribute:: Codec.frame_rates
.. autoattribute:: Codec.audio_rates
.. autoattribute:: Codec.video_formats
.. autoattribute:: Codec.audio_formats


Flags
~~~~~

.. autoattribute:: Codec.properties

.. autoclass:: Properties

    Wraps :ffmpeg:`AVCodecDescriptor.props` (``AV_CODEC_PROP_*``).

.. autoattribute:: Codec.capabilities

.. autoclass:: Capabilities

    Wraps :ffmpeg:`AVCodec.capabilities` (``AV_CODEC_CAP_*``).

    Note that ``ffmpeg -codecs`` prefers the properties versions of ``INTRA_ONLY`` and ``LOSSLESS``.

Pixel Format Selection
----------------------

.. autofunction:: find_best_pix_fmt_of_list

.. autoclass:: PixFmtLoss

    Wraps FFmpeg's ``FF_LOSS_*`` flags. Returned by
    :func:`find_best_pix_fmt_of_list` to describe what is lost when converting
    from the source pixel format to the chosen one. Being an
    :class:`enum.IntFlag`, members can be combined and tested with bitwise
    operators.

Contexts
--------

.. currentmodule:: av.codec.context
.. automodule:: av.codec.context

.. autoclass:: CodecContext

.. autoattribute:: CodecContext.codec
.. autoattribute:: CodecContext.options

.. automethod:: CodecContext.create
.. automethod:: CodecContext.open

Attributes
~~~~~~~~~~

.. autoattribute:: CodecContext.is_open
.. autoattribute:: CodecContext.is_encoder
.. autoattribute:: CodecContext.is_decoder

.. autoattribute:: CodecContext.name
.. autoattribute:: CodecContext.type
.. autoattribute:: CodecContext.profile

.. autoattribute:: CodecContext.time_base

.. autoattribute:: CodecContext.bit_rate
.. autoattribute:: CodecContext.bit_rate_tolerance
.. autoattribute:: CodecContext.max_bit_rate

.. autoattribute:: CodecContext.thread_count
.. autoattribute:: CodecContext.thread_type
.. autoattribute:: CodecContext.skip_frame

.. autoattribute:: CodecContext.extradata
.. autoattribute:: CodecContext.extradata_size

Transcoding
~~~~~~~~~~~
.. automethod:: CodecContext.parse
.. automethod:: CodecContext.encode
.. automethod:: CodecContext.decode
.. automethod:: CodecContext.flush_buffers


Enums and Flags
~~~~~~~~~~~~~~~

.. autoattribute:: CodecContext.flags

.. autoclass:: av.codec.context.Flags

    .. enumtable:: av.codec.context:Flags
        :class: av.codec.context:CodecContext

.. autoattribute:: CodecContext.flags2

.. autoclass:: av.codec.context.Flags2

    .. enumtable:: av.codec.context:Flags2
        :class: av.codec.context:CodecContext

.. autoclass:: av.codec.context.ThreadType

    Which multithreading methods to use.
    Use of FF_THREAD_FRAME will increase decoding delay by one frame per thread,
    so clients which cannot provide future frames should not use it.

    .. enumtable:: av.codec.context.ThreadType


Hardware Acceleration
---------------------

.. currentmodule:: av.codec.hwaccel
.. automodule:: av.codec.hwaccel

.. autoclass:: HWAccel

.. autofunction:: hwdevices_available

To decode on a hardware device, pass an :class:`HWAccel` to :func:`av.open`::

    import av
    from av.codec.hwaccel import HWAccel

    hwaccel = HWAccel(device_type="videotoolbox")
    with av.open("input.mp4", hwaccel=hwaccel) as container:
        for frame in container.decode(video=0):
            ...  # Frames are downloaded to system memory by default.

To encode on a hardware device, pass one to :meth:`OutputContainer.add_stream
<av.container.OutputContainer.add_stream>` with a hardware encoder. Software
frames passed to ``encode`` are uploaded to the device automatically::

    with av.open("output.mp4", "w") as container:
        stream = container.add_stream(
            "h264_videotoolbox", rate=30, hwaccel=HWAccel(device_type="videotoolbox")
        )
        ...

See ``examples/basics/hw_decode.py`` for a complete example, including
recommended device types per platform.


