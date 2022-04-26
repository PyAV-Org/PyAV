import av

from .common import TestCase


# RTSP stream server, thanks https://github.com/rtspstream
RTSP_STREAM = "rtsp://rtsp.stream/pattern"
UNIX_TIMESTAMP_2022_01_01_00_00 = 1640995200000000  # microseconds


class TestRTSPStartTimeRealtime(TestCase):
    def test_rtsp_start_time_realtime(self):
        stream_options = {
            'rtsp_transport': 'tcp',  # preferred stable connection
            'stimeout': '5000000'  # socket timeout to 5s (default is unlimited)
        }
        with av.open(RTSP_STREAM, mode="r", options=stream_options) as container:
            # wait for proper value set by RTSP in libavformat
            while container.demux(container.streams.video[0]):
                # it is okay to have None type at first dozens packets
                if container.start_time_realtime is None:
                    continue
                # Now value is ready, check this and go outside loop
                else:
                    self.assertIsInstance(container.start_time_realtime, int)
                    break

            self.assertGreater(container.start_time_realtime, UNIX_TIMESTAMP_2022_01_01_00_00)
