import socket
import threading
import time

import pytest

import av

from .common import TestCase

# The main thread sleeps in 1 ms slices while another thread is stuck in the
# RTMP handshake. It wakes roughly a thousand times if the GIL is free and a
# handful of times if it is not, so this threshold sits well clear of both.
WINDOW = 1.0
MIN_TICKS = 100


class SilentServer:
    """Accepts connections and then says nothing, so the handshake never ends."""

    def __init__(self) -> None:
        self.sock = socket.socket()
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.listen(4)
        self.port: int = self.sock.getsockname()[1]
        self.accepted: list[socket.socket] = []
        self.thread = threading.Thread(target=self._accept, daemon=True)
        self.thread.start()

    def _accept(self) -> None:
        while True:
            try:
                conn, _ = self.sock.accept()
            except OSError:
                return
            self.accepted.append(conn)

    def close(self) -> None:
        self.sock.close()
        for conn in self.accepted:
            conn.close()


def has_rtmp() -> bool:
    """Whether FFmpeg was built with the RTMP protocol.

    Port 1 on loopback refuses at once, so the probe either fails looking the
    protocol up, before any connect, or fails connecting.
    """
    try:
        with av.open("rtmp://127.0.0.1:1/x", "w", format="flv", timeout=1) as container:
            container.start_encoding()
    except av.error.ProtocolNotFoundError:
        return False
    except Exception:
        pass
    return True


@pytest.mark.skipif(not has_rtmp(), reason="FFmpeg was built without RTMP")
class TestOutputBlocking(TestCase):
    def setUp(self) -> None:
        self.server = SilentServer()

    def tearDown(self) -> None:
        self.server.close()

    def _push(
        self, timeout: float, containers: list | None = None
    ) -> tuple[threading.Thread, list[BaseException]]:
        raised: list[BaseException] = []

        def run() -> None:
            try:
                container = av.open(
                    f"rtmp://127.0.0.1:{self.server.port}/live/x",
                    "w",
                    format="flv",
                    timeout=timeout,
                )
                if containers is not None:
                    containers.append(container)
                stream = container.add_stream("h264", rate=30)
                stream.width = 320
                stream.height = 240
                stream.pix_fmt = "yuv420p"
                container.start_encoding()
            except BaseException as e:
                raised.append(e)

        thread = threading.Thread(target=run, daemon=True)
        thread.start()
        return thread, raised

    def test_start_encoding_releases_the_gil(self) -> None:
        thread, _ = self._push(WINDOW * 3)

        ticks = 0
        deadline = time.monotonic() + WINDOW
        while time.monotonic() < deadline:
            ticks += 1
            time.sleep(0.001)

        assert thread.is_alive(), "the handshake completed, so nothing was blocking"
        assert ticks > MIN_TICKS, f"main thread only ran {ticks} times"
        thread.join(WINDOW * 8)

    def test_start_encoding_honours_the_timeout(self) -> None:
        thread, raised = self._push(WINDOW)
        thread.join(WINDOW * 8)
        assert not thread.is_alive(), "timeout did not interrupt the handshake"
        assert raised, "the handshake returned instead of timing out"

    def test_close_refuses_to_free_a_container_in_use(self) -> None:
        containers: list[av.container.OutputContainer] = []
        thread, _ = self._push(WINDOW * 2, containers)

        # The server only accepts once the writing thread is inside the
        # connect, which is where the context stops being ours to free.
        deadline = time.monotonic() + WINDOW
        while not self.server.accepted and time.monotonic() < deadline:
            time.sleep(0.001)
        assert self.server.accepted, "the writing thread never connected"

        with pytest.raises(RuntimeError, match="another thread"):
            containers[0].close()
        thread.join(WINDOW * 8)


class TestFailedHeaderWrite(TestCase):
    def test_a_failed_header_write_closes_the_connection(self) -> None:
        """mp4 cannot carry PCM, so the muxer rejects it after the connect."""
        server = SilentServer()
        self.addCleanup(server.close)

        container = av.open(f"tcp://127.0.0.1:{server.port}", "w", format="mp4")
        container.add_stream("pcm_s16le")
        with pytest.raises(av.error.ArgumentError):
            container.start_encoding()

        deadline = time.monotonic() + WINDOW
        while not server.accepted and time.monotonic() < deadline:
            time.sleep(0.001)
        assert server.accepted, "the writer never connected"

        # started was never set, so nothing downstream would close pb.
        conn = server.accepted[0]
        conn.settimeout(WINDOW)
        try:
            while conn.recv(4096):
                pass  # Drain whatever the muxer wrote before it gave up.
        except TimeoutError:
            raise AssertionError("the connection was left open") from None
