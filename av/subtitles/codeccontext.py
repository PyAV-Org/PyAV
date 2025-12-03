import cython
from cython.cimports import libav as lib
from cython.cimports.av.bytesource import ByteSource, bytesource
from cython.cimports.av.error import err_check
from cython.cimports.av.packet import Packet
from cython.cimports.av.subtitles.subtitle import SubtitleProxy, SubtitleSet
from cython.cimports.cpython.bytes import PyBytes_FromStringAndSize
from cython.cimports.libc.string import memcpy, strlen


@cython.cclass
class SubtitleCodecContext(CodecContext):
    @property
    def subtitle_header(self) -> bytes | None:
        """Get the subtitle header data (ASS/SSA format for text subtitles)."""
        if (
            self.ptr.subtitle_header == cython.NULL
            or self.ptr.subtitle_header_size <= 0
        ):
            return None
        return PyBytes_FromStringAndSize(
            cython.cast(cython.p_char, self.ptr.subtitle_header),
            self.ptr.subtitle_header_size,
        )

    @subtitle_header.setter
    def subtitle_header(self, data: bytes | None) -> None:
        """Set the subtitle header data."""
        source: ByteSource
        if data is None:
            lib.av_freep(cython.address(self.ptr.subtitle_header))
            self.ptr.subtitle_header_size = 0
        else:
            source = bytesource(data)
            self.ptr.subtitle_header = cython.cast(
                cython.p_uchar,
                lib.av_realloc(
                    self.ptr.subtitle_header,
                    source.length + lib.AV_INPUT_BUFFER_PADDING_SIZE,
                ),
            )
            if not self.ptr.subtitle_header:
                raise MemoryError("Cannot allocate subtitle_header")
            memcpy(self.ptr.subtitle_header, source.ptr, source.length)
            self.ptr.subtitle_header_size = source.length
        self.subtitle_header_set = True

    def __dealloc__(self) -> None:
        if self.ptr and self.subtitle_header_set:
            lib.av_freep(cython.address(self.ptr.subtitle_header))

    def encode_subtitle(self, subtitle: SubtitleSet) -> Packet:
        """
        Encode a SubtitleSet into a Packet.

        Args:
            subtitle: The SubtitleSet to encode

        Returns:
            A Packet containing the encoded subtitle data
        """
        if not self.codec.ptr:
            raise ValueError("Cannot encode with unknown codec")

        self.open(strict=False)

        # Calculate buffer size from subtitle text length
        buf_size: cython.size_t = 0
        i: cython.uint
        for i in range(subtitle.proxy.struct.num_rects):
            rect = subtitle.proxy.struct.rects[i]
            if rect.ass != cython.NULL:
                buf_size += strlen(rect.ass)
            if rect.text != cython.NULL:
                buf_size += strlen(rect.text)
        buf_size += 1024  # padding for format overhead

        buf: cython.p_uchar = cython.cast(cython.p_uchar, lib.av_malloc(buf_size))
        if buf == cython.NULL:
            raise MemoryError("Failed to allocate subtitle encode buffer")

        ret: cython.int = lib.avcodec_encode_subtitle(
            self.ptr,
            buf,
            buf_size,
            cython.address(subtitle.proxy.struct),
        )

        if ret < 0:
            lib.av_free(buf)
            err_check(ret, "avcodec_encode_subtitle()")

        packet: Packet = Packet(ret)
        memcpy(packet.ptr.data, buf, ret)
        lib.av_free(buf)

        packet.ptr.pts = subtitle.proxy.struct.pts
        packet.ptr.dts = subtitle.proxy.struct.pts
        packet.ptr.duration = (
            subtitle.proxy.struct.end_display_time
            - subtitle.proxy.struct.start_display_time
        )

        return packet

    @cython.cfunc
    def _send_packet_and_recv(self, packet: Packet | None):
        if packet is None:
            raise RuntimeError("packet cannot be None")

        proxy: SubtitleProxy = SubtitleProxy()
        got_frame: cython.int = 0

        err_check(
            lib.avcodec_decode_subtitle2(
                self.ptr,
                cython.address(proxy.struct),
                cython.address(got_frame),
                packet.ptr,
            )
        )

        if got_frame:
            return SubtitleSet(proxy)
        return []

    @cython.ccall
    def decode2(self, packet: Packet):
        """
        Returns SubtitleSet if you really need it.
        """
        if not self.codec.ptr:
            raise ValueError("cannot decode unknown codec")

        self.open(strict=False)

        proxy: SubtitleProxy = SubtitleProxy()
        got_frame: cython.int = 0

        err_check(
            lib.avcodec_decode_subtitle2(
                self.ptr,
                cython.address(proxy.struct),
                cython.address(got_frame),
                packet.ptr,
            )
        )

        if got_frame:
            return SubtitleSet(proxy)
        return None
