
Streams
=======


Stream collections
------------------

.. currentmodule:: av.container.streams

.. autoclass:: StreamContainer


Dynamic Slicing
~~~~~~~~~~~~~~~

.. automethod:: StreamContainer.get

.. automethod:: StreamContainer.best


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

.. attribute:: StreamContainer.attachments

    A tuple of :class:`AttachmentStream`.

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


Timing
~~~~~~

.. seealso:: :ref:`time` for a discussion of time in general.

.. autoattribute:: Stream.time_base

.. autoattribute:: Stream.start_time

.. autoattribute:: Stream.duration

.. autoattribute:: Stream.frames


Others
~~~~~~

.. autoattribute:: Stream.profile

.. autoattribute:: Stream.language



