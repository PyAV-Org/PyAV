from av.stream cimport Stream


cdef class AttachmentStream(Stream):
    """
    An :class:`AttachmentStream`.
    """

    @property
    def name(self):
        return self.metadata.get("filename")

    @property
    def mimetype(self):
        return self.metadata.get("mimetype")
