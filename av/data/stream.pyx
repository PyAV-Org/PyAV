cimport libav as lib

cdef class DataStream(Stream):


    def __repr__(self):
        return '<av.%s #%d %s/%s at 0x%x>' % (
            self.__class__.__name__,
            self.index,
            self.type or '<notype>',
            self.name or '<nocodec>',
            id(self),
        )


    def encode(self, frame=None):
        pass

    def decode(self, packet=None, count=0):
        pass

    def seek(self, timestamp, mode='time', backward=True, any_frame=False):
        pass

    # must be none to avoid infinite loop in Stream.__getattr__
    property codec:
        def __get__(self):
            return None

    property name:
        def __get__(self):
            cdef const lib.AVCodecDescriptor *desc = lib.avcodec_descriptor_get(self._codec_context.codec_id)
            if desc == NULL:
                return None
            return desc.name

    property type:
        def __get__(self):
            return "data"
