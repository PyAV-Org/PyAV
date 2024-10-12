Basics
======

Here are some common things to do without digging too deep into the mechanics.


Saving Keyframes
----------------

If you just want to look at keyframes, you can set :attr:`.CodecContext.skip_frame` to speed up the process:

.. literalinclude:: ../../examples/basics/save_keyframes.py


Remuxing
--------

Remuxing is copying audio/video data from one container to the other without transcoding. By doing so, the data does not suffer any generational loss, and is the full quality that it was in the source container.

.. literalinclude:: ../../examples/basics/remux.py


Parsing
-------

Sometimes we have a raw stream of data, and we need to split it into packets before working with it. We can use :meth:`.CodecContext.parse` to do this.

.. literalinclude:: ../../examples/basics/parse.py


Threading
---------

By default, codec contexts will decode with :data:`~av.codec.context.ThreadType.SLICE` threading. This allows multiple threads to cooperate to decode any given frame.

This is faster than no threading, but is not as fast as we can go.

Also enabling :data:`~av.codec.context.ThreadType.FRAME` (or :data:`~av.codec.context.ThreadType.AUTO`) threading allows multiple threads to decode independent frames. This is not enabled by default because it does change the API a bit: you will get a much larger "delay" between starting the decode of a packet and getting it's results. Take a look at the output of this sample to see what we mean:

.. literalinclude:: ../../examples/basics/thread_type.py

On the author's machine, the second pass decodes ~5 times faster.


Recording the Screen
--------------------

.. literalinclude:: ../../examples/basics/record_screen.py


Recording a Facecam
-------------------

.. literalinclude:: ../../examples/basics/record_facecam.py

