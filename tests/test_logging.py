from __future__ import division

from .common import *

import logging
import threading

import av.logging
import av.utils


def do_log(message):
    av.logging.log(av.logging.INFO, 'test', message)


class TestLogging(TestCase):

    def test_adapt_level(self):
        self.assertEqual(
            av.logging.adapt_level(av.logging.ERROR),
            logging.ERROR
        )
        self.assertEqual(
            av.logging.adapt_level(av.logging.WARNING),
            logging.WARNING
        )
        self.assertEqual(
            av.logging.adapt_level((av.logging.WARNING + av.logging.ERROR) // 2),
            logging.WARNING
        )

    def test_threaded_captures(self):

        with av.logging.Capture(local=True) as logs:
            do_log('main')
            thread = threading.Thread(target=do_log, args=('thread', ))
            thread.start()
            thread.join()

        self.assertEqual(logs, [
            (av.logging.INFO, 'test', 'main'),
        ])

    def test_global_captures(self):

        with av.logging.Capture(local=False) as logs:
            do_log('main')
            thread = threading.Thread(target=do_log, args=('thread', ))
            thread.start()
            thread.join()

        self.assertEqual(logs, [
            (av.logging.INFO, 'test', 'main'),
            (av.logging.INFO, 'test', 'thread'),
        ])

    def test_repeats(self):

        with av.logging.Capture() as logs:
            do_log('foo')
            do_log('foo')
            do_log('bar')
            do_log('bar')
            do_log('bar')
            do_log('baz')

        logs = [l for l in logs if l[1] == 'test']

        self.assertEqual(logs, [
            (av.logging.INFO, 'test', 'foo'),
            (av.logging.INFO, 'test', 'foo'),
            (av.logging.INFO, 'test', 'bar'),
            (av.logging.INFO, 'test', 'bar (repeated 2 more times)'),
            (av.logging.INFO, 'test', 'baz'),

        ])

    def test_error(self):

        log = (av.logging.ERROR, 'test', 'This is a test.')
        av.logging.log(*log)
        try:
            av.utils.err_check(-1)
        except AVError as e:
            self.assertEqual(e.log, log)
        else:
            self.fail()
