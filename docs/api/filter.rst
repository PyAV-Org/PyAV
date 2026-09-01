Filters
=======

.. automodule:: av.filter.filter

    .. autoclass:: Filter
        :members:


.. automodule:: av.filter.graph

    .. autoclass:: Graph
        :members:

Hardware filters which create frames need an :class:`~av.codec.hwaccel.HWDevice`
when the graph is constructed. The graph shares that device with every filter
which requests one before the filter is initialized::

    from av.codec.hwaccel import HWDevice
    from av.filter import Graph

    device = HWDevice("vaapi")
    graph = Graph(hw_device=device)


.. automodule:: av.filter.context

    .. autoclass:: FilterContext
        :members:


.. automodule:: av.filter.link

    .. autoclass:: FilterLink
        :members:
