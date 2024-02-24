cimport libav as lib


cdef class DataStream(Stream):
    def __repr__(self):
        cls_name = self.__class__.__name__
        _type = self.type or "<notype>"
        name = self.name or "<nocodec>"

        return f"<av.{cls_name} #{self.index} {_type}/{name} at 0x{id(self):x}>"

    def encode(self, frame=None):
        return []

    def decode(self, packet=None, count=0):
        return []

    @property
    def name(self):
        cdef const lib.AVCodecDescriptor *desc = lib.avcodec_descriptor_get(self.ptr.codecpar.codec_id)
        if desc == NULL:
            return None
        return desc.name
