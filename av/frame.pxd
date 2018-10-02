cimport libav as lib

from av.packet cimport Packet


cdef class Frame(object):

    cdef lib.AVFrame *ptr

    # We define our own time.
    cdef lib.AVRational _time_base
    cdef _rebase_time(self, lib.AVRational)

    cdef readonly int index

    cdef readonly tuple planes
    """
    A tuple of :class:`~av.audio.plane.AudioPlane` or :class:`~av.video.plane.VideoPlane` objects.

    :type: tuple
    """

    cdef _init_planes(self, cls=?)
    cdef int _max_plane_count(self)

    cdef _copy_internal_attributes(self, Frame source, bint data_layout=?)

    cdef _init_user_attributes(self)
