import cython
from cython.cimports import libav as lib
from cython.cimports.av.error import err_check
from cython.cimports.av.packet import Packet
from cython.cimports.av.subtitles.subtitle import SubtitleProxy, SubtitleSet


@cython.cclass
class SubtitleCodecContext(CodecContext):
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
