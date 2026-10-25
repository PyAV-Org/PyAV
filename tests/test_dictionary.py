import pytest

from av.dictionary import Dictionary


def test_dictionary() -> None:
    d = Dictionary()
    d["key"] = "value"

    assert d["key"] == "value"
    assert "key" in d
    assert len(d) == 1
    assert list(d) == ["key"]

    assert d.pop("key") == "value"
    pytest.raises(KeyError, d.pop, "key")
    assert len(d) == 0


def test_dictionary_non_ascii() -> None:
    d = Dictionary()
    d["café"] = "naïve 日本語 🎵"

    assert d["café"] == "naïve 日本語 🎵"
    assert "café" in d
    assert list(d) == ["café"]


def test_dictionary_mutate_while_iterating() -> None:
    d = Dictionary({"a": "1", "b": "2"})
    # Iteration used to hold an entry pointer that inserts could invalidate.
    for key in d:
        for i in range(100):
            d[f"{key}{i}"] = "x"
    assert len(d) == 202
