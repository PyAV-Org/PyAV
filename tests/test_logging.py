import errno
import logging
import threading

import av.error
import av.logging


def do_log(message: str) -> None:
    av.logging.log(av.logging.INFO, "test", message)


def test_adapt_level() -> None:
    assert av.logging.adapt_level(av.logging.ERROR) == logging.ERROR
    assert av.logging.adapt_level(av.logging.WARNING) == logging.WARNING
    assert (
        av.logging.adapt_level((av.logging.WARNING + av.logging.ERROR) // 2)
        == logging.WARNING
    )


def test_threaded_captures() -> None:
    av.logging.set_level(av.logging.VERBOSE)

    with av.logging.Capture(local=True) as logs:
        do_log("main")
        thread = threading.Thread(target=do_log, args=("thread",))
        thread.start()
        thread.join()

    assert (av.logging.INFO, "test", "main") in logs
    av.logging.set_level(None)


def test_global_captures() -> None:
    av.logging.set_level(av.logging.VERBOSE)

    with av.logging.Capture(local=False) as logs:
        do_log("main")
        thread = threading.Thread(target=do_log, args=("thread",))
        thread.start()
        thread.join()

    assert (av.logging.INFO, "test", "main") in logs
    assert (av.logging.INFO, "test", "thread") in logs
    av.logging.set_level(None)


def test_repeats() -> None:
    av.logging.set_level(av.logging.VERBOSE)

    with av.logging.Capture() as logs:
        do_log("foo")
        do_log("foo")
        do_log("bar")
        do_log("bar")
        do_log("bar")
        do_log("baz")

    logs = [log for log in logs if log[1] == "test"]

    assert logs == [
        (av.logging.INFO, "test", "foo"),
        (av.logging.INFO, "test", "foo"),
        (av.logging.INFO, "test", "bar"),
        (av.logging.INFO, "test", "bar (repeated 2 more times)"),
        (av.logging.INFO, "test", "baz"),
    ]

    av.logging.set_level(None)


def test_error() -> None:
    av.logging.set_level(av.logging.VERBOSE)

    log = (av.logging.ERROR, "test", "This is a test.")
    av.logging.log(*log)
    try:
        av.error.err_check(-errno.EPERM)
    except av.error.PermissionError as e:
        assert e.log == log
    else:
        assert False

    av.logging.set_level(None)
