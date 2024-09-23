import errno
import logging
import threading

import av.error
import av.logging

from .common import TestCase


def do_log(message):
    av.logging.log(av.logging.INFO, "test", message)


class TestLogging(TestCase):
    def test_adapt_level(self):
        assert av.logging.adapt_level(av.logging.ERROR) == logging.ERROR
        assert av.logging.adapt_level(av.logging.WARNING) == logging.WARNING
        self.assertEqual(
            av.logging.adapt_level((av.logging.WARNING + av.logging.ERROR) // 2),
            logging.WARNING,
        )

    def test_threaded_captures(self):
        av.logging.set_level(av.logging.VERBOSE)

        with av.logging.Capture(local=True) as logs:
            do_log("main")
            thread = threading.Thread(target=do_log, args=("thread",))
            thread.start()
            thread.join()

        self.assertIn((av.logging.INFO, "test", "main"), logs)
        av.logging.set_level(None)

    def test_global_captures(self):
        av.logging.set_level(av.logging.VERBOSE)

        with av.logging.Capture(local=False) as logs:
            do_log("main")
            thread = threading.Thread(target=do_log, args=("thread",))
            thread.start()
            thread.join()

        self.assertIn((av.logging.INFO, "test", "main"), logs)
        self.assertIn((av.logging.INFO, "test", "thread"), logs)
        av.logging.set_level(None)

    def test_repeats(self):
        av.logging.set_level(av.logging.VERBOSE)

        with av.logging.Capture() as logs:
            do_log("foo")
            do_log("foo")
            do_log("bar")
            do_log("bar")
            do_log("bar")
            do_log("baz")

        logs = [log for log in logs if log[1] == "test"]

        self.assertEqual(
            logs,
            [
                (av.logging.INFO, "test", "foo"),
                (av.logging.INFO, "test", "foo"),
                (av.logging.INFO, "test", "bar"),
                (av.logging.INFO, "test", "bar (repeated 2 more times)"),
                (av.logging.INFO, "test", "baz"),
            ],
        )

        av.logging.set_level(None)

    def test_error(self):
        av.logging.set_level(av.logging.VERBOSE)

        log = (av.logging.ERROR, "test", "This is a test.")
        av.logging.log(*log)
        try:
            av.error.err_check(-errno.EPERM)
        except OSError as e:
            assert e.log == log
        else:
            self.fail()

        av.logging.set_level(None)
