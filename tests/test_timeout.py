import threading
import time
from http.server import BaseHTTPRequestHandler
from socketserver import TCPServer

import av

from .common import TestCase, fate_suite

PORT = 8002
CONTENT = open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb").read()
# Needs to be long enough for all host OSes to deal.
TIMEOUT = 0.25
DELAY = 4 * TIMEOUT


class HttpServer(TCPServer):
    allow_reuse_address = True

    def handle_error(self, request: object, client_address: object) -> None:
        pass


class SlowRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        time.sleep(DELAY)
        self.send_response(200)
        self.send_header("Content-Length", str(len(CONTENT)))
        self.end_headers()
        self.wfile.write(CONTENT)

    def log_message(self, format: object, *args: object) -> None:
        pass


class TestTimeout(TestCase):
    def setUp(cls) -> None:
        cls._server = HttpServer(("", PORT), SlowRequestHandler)
        cls._thread = threading.Thread(target=cls._server.handle_request)
        cls._thread.daemon = True  # Make sure the tests will exit.
        cls._thread.start()

    def tearDown(cls) -> None:
        cls._thread.join(1)  # Can't wait forever or the tests will never exit.
        cls._server.server_close()

    def test_no_timeout(self) -> None:
        start = time.time()
        av.open(f"http://localhost:{PORT}/mpeg2_field_encoding.ts")
        duration = time.time() - start
        assert duration > DELAY

    def test_open_timeout(self) -> None:
        with self.assertRaises(av.ExitError):
            start = time.time()
            av.open(f"http://localhost:{PORT}/mpeg2_field_encoding.ts", timeout=TIMEOUT)

        duration = time.time() - start
        assert duration < DELAY

    def test_open_timeout_2(self) -> None:
        with self.assertRaises(av.ExitError):
            start = time.time()
            av.open(
                f"http://localhost:{PORT}/mpeg2_field_encoding.ts",
                timeout=(TIMEOUT, None),
            )

        duration = time.time() - start
        assert duration < DELAY
