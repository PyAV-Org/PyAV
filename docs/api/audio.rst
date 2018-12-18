
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
        :exclude-members: channel_layout, channels

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

    .. autoclass:: AudioChannel
        :members:

Audio Frames
------------

.. automodule:: av.audio.frame

    .. autoclass:: AudioFrame
        :members:
        :exclude-members: to_nd_array

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
