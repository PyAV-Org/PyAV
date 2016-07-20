import os
import shutil
import threading
import time

import av

from .common import TestCase, fate_suite


try:
    # Python 3
    from http.server import BaseHTTPRequestHandler
    from socketserver import TCPServer
except ImportError:
    # Python 2
    from BaseHTTPServer import BaseHTTPRequestHandler
    from SocketServer import TCPServer


PORT = 8002
FILE_PATH = fate_suite('mpeg2/mpeg2_field_encoding.ts')


class HttpServer(TCPServer):
    allow_reuse_address = True

    def handle_error(self, request, client_address):
        pass


class SlowRequestHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(2)
        with open(FILE_PATH, 'rb') as fp:
            self.send_response(200)
            self.send_header('Content-Length', str(os.fstat(fp.fileno()).st_size))
            self.end_headers()
            shutil.copyfileobj(fp, self.wfile)

    def log_message(self, format, *args):
        pass


class TestTimeout(TestCase):
    def setUp(cls):
        cls._server = HttpServer(('', PORT), SlowRequestHandler)
        cls._thread = threading.Thread(target=cls._server.handle_request)
        cls._thread.start()

    def tearDown(cls):
        cls._thread.join()
        cls._server.server_close()

    def test_no_timeout(self):
        av.open('http://localhost:%d/mpeg2_field_encoding.ts' % PORT)

    def test_open_timeout(self):
        with self.assertRaises(av.AVError) as cm:
            av.open('http://localhost:%d/mpeg2_field_encoding.ts' % PORT, timeout=1)
        self.assertTrue('Immediate exit requested' in str(cm.exception))

    def test_open_timeout_2(self):
        with self.assertRaises(av.AVError) as cm:
            av.open('http://localhost:%d/mpeg2_field_encoding.ts' % PORT, timeout=(1, None))
        self.assertTrue('Immediate exit requested' in str(cm.exception))
