from http.server import BaseHTTPRequestHandler
from socketserver import TCPServer
import threading
import time

import av

from .common import TestCase, fate_suite


PORT = 8002
CONTENT = open(fate_suite("mpeg2/mpeg2_field_encoding.ts"), "rb").read()
# Needs to be long enough for all host OSes to deal.
TIMEOUT = 0.25
DELAY = 4 * TIMEOUT


class HttpServer(TCPServer):
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        pass


class SlowRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(DELAY)
        self.send_response(200)
        self.send_header("Content-Length", str(len(CONTENT)))
        self.end_headers()
        self.wfile.write(CONTENT)

    def log_message(self, format, *args):
        pass


class TestTimeout(TestCase):
    def setUp(cls):
        cls._server = HttpServer(("", PORT), SlowRequestHandler)
        cls._thread = threading.Thread(target=cls._server.handle_request)
        cls._thread.daemon = True  # Make sure the tests will exit.
        cls._thread.start()

    def tearDown(cls):
        cls._thread.join(1)  # Can't wait forever or the tests will never exit.
        cls._server.server_close()

    def test_no_timeout(self):
        start = time.time()
        av.open("http://localhost:%d/mpeg2_field_encoding.ts" % PORT)
        duration = time.time() - start
        self.assertGreater(duration, DELAY)

    def test_open_timeout(self):
        with self.assertRaises(av.ExitError):
            start = time.time()
            av.open(
                "http://localhost:%d/mpeg2_field_encoding.ts" % PORT, timeout=TIMEOUT
            )
        duration = time.time() - start
        self.assertLess(duration, DELAY)

    def test_open_timeout_2(self):
        with self.assertRaises(av.ExitError):
            start = time.time()
            av.open(
                "http://localhost:%d/mpeg2_field_encoding.ts" % PORT,
                timeout=(TIMEOUT, None),
            )
        duration = time.time() - start
        self.assertLess(duration, DELAY)
