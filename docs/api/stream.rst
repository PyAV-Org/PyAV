
Streams
=======


Stream collections
------------------

.. currentmodule:: av.container.streams

.. autoclass:: StreamContainer


Dynamic Slicing
~~~~~~~~~~~~~~~

.. automethod:: StreamContainer.get


Typed Collections
~~~~~~~~~~~~~~~~~

These attributes are preferred for readability if you don't need the
dynamic capabilities of :meth:`.get`:

.. attribute:: StreamContainer.video

    A tuple of :class:`VideoStream`.

.. attribute:: StreamContainer.audio

    A tuple of :class:`AudioStream`.

.. attribute:: StreamContainer.subtitles

    A tuple of :class:`SubtitleStream`.

.. attribute:: StreamContainer.data

    A tuple of :class:`DataStream`.

.. attribute:: StreamContainer.other

    A tuple of :class:`Stream`


Streams
-------

.. currentmodule:: av.stream

.. autoclass:: Stream


Basics
~~~~~~


.. autoattribute:: Stream.type

.. autoattribute:: Stream.codec_context

.. autoattribute:: Stream.id

.. autoattribute:: Stream.index


Transcoding
~~~~~~~~~~~

.. automethod:: Stream.encode

.. automethod:: Stream.decode


Timing
~~~~~~

.. seealso:: :ref:`time` for a discussion of time in general.

.. autoattribute:: Stream.time_base

.. autoattribute:: Stream.start_time

.. autoattribute:: Stream.duration

.. autoattribute:: Stream.frames


.. _frame_rates:

Frame Rates
...........


These attributes are different ways of calculating frame rates.

Since containers don't need to explicitly identify a frame rate, nor
even have a static frame rate, these attributes are not guaranteed to be accurate.
You must experiment with them with your media to see which ones work for you for your purposes.

Whenever possible, we advise that you use raw timing instead of frame rates.

.. autoattribute:: Stream.average_rate

.. autoattribute:: Stream.base_rate

.. autoattribute:: Stream.guessed_rate


Others
~~~~~~

.. automethod:: Stream.seek

.. autoattribute:: Stream.profile

.. autoattribute:: Stream.language



