import av
import fs
import base64

from .common import TestCase, fate_suite


class TestDataStream(TestCase):

    def add_empty_klv_stream(self, context):
        # base64-encoded bytes that describe a ts file with one klv stream containing one packet.
        dummy_str = 'R0AREABC8CUAAcEAAP8B/wAB/IAUSBIBBkZGbXBlZwlTZXJ2aWNlMDF3fEPK//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////9HQAAQAACwDQABwQAAAAHwACqxBLL//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////0dQABAAArAYAAHBAADhAPAABuEA8AYFBEtMVkEbIMiL////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////R0EAMKhQAAAAAH4A//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////8AAAH8AAmEgAUhAAEAAQA='

        data = base64.b64decode(dummy_str)

        mem_fs = fs.open_fs('mem://')
        with mem_fs.open('dummy.ts', 'wb') as dummy:
            dummy.write(data)

        out_stream = None

        with mem_fs.open('dummy.ts', 'rb') as dummy:
            dummy_context = av.open(dummy)
            out_stream = context.add_stream(template=dummy_context.streams.data[0])
            dummy_context.close()
            dummy_context = None

        mem_fs.close()

        return out_stream

    def test_selection(self):
        mem_fs = fs.open_fs('mem://')
        with mem_fs.open('dummy_out.ts', 'wb') as dummy:
            out_context = av.open(dummy, 'w', format='mpegts')
            self.assertEqual(0, len(out_context.streams.data))
            self.add_empty_klv_stream(out_context)
            self.assertEqual(1, len(out_context.streams.data))

        mem_fs.close()