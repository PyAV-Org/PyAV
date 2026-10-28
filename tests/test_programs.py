from collections import Counter

import pytest

import av
from av.container.input import Program
from av.stream import Discard

from .common import fate_suite


def test_programs() -> None:
    with av.open(fate_suite("mpegts/loewe.ts")) as container:
        programs = container.programs
        assert len(programs) == 1

        program = programs[0]
        assert isinstance(program, Program)
        assert program.index == 0
        assert program.id == 769
        assert program.program_num == 769
        assert program.pmt_pid == 1363
        assert program.pcr_pid == 1361
        assert program.metadata == {
            "service_name": "Das Erste HD",
            "service_provider": "LOEWE. DR+",
        }
        assert program.streams == (container.streams[0], container.streams[1])
        assert program.discard == Discard.none
        assert repr(program).startswith("<av.Program #0 id=769, 2 streams at ")


def test_programs_discard() -> None:
    path = fate_suite("mpegts/loewe.ts")
    with av.open(path) as container:
        counts = Counter(p.stream_index for p in container.demux() if p.size)
    assert set(counts) == {0, 1, 2}

    with av.open(path) as container:
        program = container.programs[0]
        program.discard = Discard.all
        assert program.discard == Discard.all
        counts = Counter(p.stream_index for p in container.demux() if p.size)

    # Stream 2 is not part of the program, so it is still read.
    assert set(counts) == {2}


def test_programs_none() -> None:
    with av.open(fate_suite("h264/interlaced_crop.mp4")) as container:
        assert container.programs == ()


def test_program_after_close() -> None:
    container = av.open(fate_suite("mpegts/loewe.ts"))
    program = container.programs[0]
    container.close()

    assert "container closed" in repr(program)
    with pytest.raises(AssertionError):
        program.id


def test_program_cannot_be_instantiated() -> None:
    with pytest.raises(RuntimeError):
        Program(None)  # type: ignore[call-arg]
