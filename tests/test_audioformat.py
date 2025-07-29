import sys

import pytest

from av import AudioFormat


def test_s16_inspection() -> None:
    fmt = AudioFormat("s16")
    postfix = "le" if sys.byteorder == "little" else "be"

    assert fmt.name == "s16"
    assert not fmt.is_planar
    assert fmt.bits == 16
    assert fmt.bytes == 2
    assert fmt.container_name == "s16" + postfix
    assert fmt.planar.name == "s16p"
    assert fmt.packed is fmt


def test_s32p_inspection() -> None:
    fmt = AudioFormat("s32p")
    assert fmt.name == "s32p"
    assert fmt.is_planar
    assert fmt.bits == 32
    assert fmt.bytes == 4

    pytest.raises(ValueError, lambda: fmt.container_name)
