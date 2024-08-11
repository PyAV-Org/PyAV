from av.stream cimport Stream


cdef class AttachmentStream(Stream):
    """
    An :class:`AttachmentStream` represents a stream of attachment data within a media container.
    Typically used to attach font files that are referenced in ASS/SSA Subtitle Streams.
    """

    @property
    def name(self):
        """
        Returns the file name of the attachment.

        :rtype: str | None
        """
        return self.metadata.get("filename")

    @property
    def mimetype(self):
        """
        Returns the MIME type of the attachment.

        :rtype: str | None
        """
        return self.metadata.get("mimetype")
