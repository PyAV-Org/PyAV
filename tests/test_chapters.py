from fractions import Fraction

import av

from .common import fate_suite


def test_chapters() -> None:
    expected = [
        {
            "id": 1,
            "start": 0,
            "end": 5000,
            "time_base": Fraction(1, 1000),
            "metadata": {"title": "start"},
        },
        {
            "id": 2,
            "start": 5000,
            "end": 10500,
            "time_base": Fraction(1, 1000),
            "metadata": {"title": "Five Seconds"},
        },
        {
            "id": 3,
            "start": 10500,
            "end": 15000,
            "time_base": Fraction(1, 1000),
            "metadata": {"title": "Ten point 5 seconds"},
        },
        {
            "id": 4,
            "start": 15000,
            "end": 19849,
            "time_base": Fraction(1, 1000),
            "metadata": {"title": "15 sec - over soon"},
        },
    ]
    path = fate_suite("vorbis/vorbis_chapter_extension_demo.ogg")
    with av.open(path) as container:
        assert container.chapters() == expected


def test_set_chapters() -> None:
    chapters: list[av.container.Chapter] = [
        {
            "id": 1,
            "start": 0,
            "end": 5000,
            "time_base": Fraction(1, 1000),
            "metadata": {"title": "start"},
        }
    ]

    path = fate_suite("h264/interlaced_crop.mp4")
    with av.open(path) as container:
        container.set_chapters(chapters)
        assert container.chapters() == chapters
