import sys

import pytest

import av
import av.logging

# Since Python 3.12, True, False, and None are immortal, and the interpreter
# hands out references to them without incrementing their refcount. Extension
# code compiled against older headers still decrements that refcount when it
# releases such a reference, so each discarded comparison result or `with` lock
# costs True one count. After about 2**30 of them, Python 3.14 no longer treats
# True as immortal and truth tests on it start failing. The cp311-abi3 wheels of
# PyAV 17 and 18 were compiled against Python 3.11 headers and did this.


def singleton_refcounts() -> tuple[int, int, int]:
    return sys.getrefcount(True), sys.getrefcount(False), sys.getrefcount(None)


def log_and_fail_to_open() -> None:
    av.logging.log(av.logging.ERROR, "test", "message")
    with pytest.raises(FileNotFoundError):
        av.open("/nonexistent/file.mp4")


@pytest.mark.skipif(
    sys.implementation.name != "cpython" or sys.version_info < (3, 12),
    reason="immortal objects are CPython 3.12+",
)
def test_immortal_refcounts_unchanged() -> None:
    av.logging.set_level(av.logging.FATAL)
    try:
        log_and_fail_to_open()
        before = singleton_refcounts()
        for _ in range(100):
            log_and_fail_to_open()
        after = singleton_refcounts()
    finally:
        av.logging.set_level(None)

    assert after == before
