
Codecs
======

Descriptors
-----------

.. automodule:: av.codec

    .. autoclass:: Codec
        :members:


Flags
~~~~~

.. autoclass:: Properties

    Various ``AV_CODEC_PROP_*`` flags in FFmpeg.

    .. seealso:: :ffmpeg:`AVCodecDescriptor.props`

.. enumtable:: av.codec.codec.Properties

.. autoclass:: Capabilities

    Various ``AV_CODEC_CAP_*`` flags in FFmpeg.

    Note that ``ffmpeg -codecs`` prefers the properties versions of
    ``INTRA_ONLY`` and ``LOSSLESS``.

    .. seealso:: :ffmpeg:`AVCodec.capabilities`

.. enumtable:: av.codec.codec.Capabilities


Contexts
--------

.. automodule:: av.codec.context

.. autoclass:: av.codec.context.CodecContext
    :members:


Flags
~~~~~

.. autoclass:: av.codec.context.ThreadType

    Which multithreading methods to use.
    Use of FF_THREAD_FRAME will increase decoding delay by one frame per thread,
    so clients which cannot provide future frames should not use it.

.. enumtable:: av.codec.context.ThreadType

.. autoclass:: av.codec.context.SkipType
.. enumtable:: av.codec.context.SkipType

.. autoclass:: av.codec.context.Flags
.. enumtable:: av.codec.context:Flags
    :class: av.codec.context:CodecContext

.. autoclass:: av.codec.context.Flags2
.. enumtable:: av.codec.context:Flags2
    :class: av.codec.context:CodecContext

