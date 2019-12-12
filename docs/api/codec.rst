
Codecs
======

Descriptors
-----------

.. currentmodule:: av.codec
.. automodule:: av.codec

.. autoclass:: Codec

.. automethod:: Codec.create

.. autoattribute:: Codec.is_encoder
.. autoattribute:: Codec.is_encoder
..
    .. autoattribute:: Codec.descriptor
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

    .. enumtable:: av.codec.codec.Properties
        :class: av.codec.codec.Codec

.. autoattribute:: Codec.capabilities

.. autoclass:: Capabilities

    Wraps :ffmpeg:`AVCodec.capabilities` (``AV_CODEC_CAP_*``).

    Note that ``ffmpeg -codecs`` prefers the properties versions of
    ``INTRA_ONLY`` and ``LOSSLESS``.

    .. enumtable:: av.codec.codec.Capabilities
        :class: av.codec.codec.Codec


Contexts
--------

.. currentmodule:: av.codec.context
.. automodule:: av.codec.context

.. autoclass:: CodecContext

.. autoattribute:: CodecContext.codec
.. autoattribute:: CodecContext.options

.. automethod:: CodecContext.create
.. automethod:: CodecContext.open
.. automethod:: CodecContext.close

Attributes
~~~~~~~~~~

.. autoattribute:: CodecContext.is_open
.. autoattribute:: CodecContext.is_encoder
.. autoattribute:: CodecContext.is_decoder

.. autoattribute:: CodecContext.name
.. autoattribute:: CodecContext.type
.. autoattribute:: CodecContext.profile

.. autoattribute:: CodecContext.time_base
.. autoattribute:: CodecContext.ticks_per_frame

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


Flags
~~~~~

.. autoattribute:: CodecContext.flags

.. autoclass:: av.codec.context.Flags

    .. enumtable:: av.codec.context:Flags
        :class: av.codec.context:CodecContext

.. autoattribute:: CodecContext.flags2

.. autoclass:: av.codec.context.Flags2

    .. enumtable:: av.codec.context:Flags2
        :class: av.codec.context:CodecContext


Enums
~~~~~

.. autoclass:: av.codec.context.ThreadType

    Which multithreading methods to use.
    Use of FF_THREAD_FRAME will increase decoding delay by one frame per thread,
    so clients which cannot provide future frames should not use it.

    .. enumtable:: av.codec.context.ThreadType

.. autoclass:: av.codec.context.SkipType

    .. enumtable:: av.codec.context.SkipType


