import pickle
from fractions import Fraction

import pytest

from av import AVRational


def test_construction() -> None:
    r = AVRational(2, 4)
    assert (r.num, r.den) == (1, 2)
    assert (AVRational(1, -2).num, AVRational(1, -2).den) == (-1, 2)
    assert AVRational(Fraction(30000, 1001)) == AVRational(30000, 1001)
    assert AVRational(10**10, 2 * 10**10) == AVRational(1, 2)
    with pytest.raises(OverflowError):
        AVRational(2**31, 3)


def test_unset_is_falsy() -> None:
    assert not AVRational()
    assert not AVRational(0, 1)
    assert AVRational(1, 25)


def test_zero_denominator() -> None:
    inf = AVRational(1, 0)
    assert not inf and not AVRational(-1, 0) and not AVRational(0, 0)
    assert (AVRational(5, 0).num, AVRational(5, 0).den) == (1, 0)
    assert (AVRational(-7, 0).num, AVRational(-7, 0).den) == (-1, 0)
    assert inf == AVRational(2, 0)
    assert inf != AVRational(0, 0) and inf != Fraction(1, 2) and inf != 1
    assert float(inf) == float("inf")
    assert float(AVRational(-1, 0)) == float("-inf")
    assert str(float(AVRational(0, 0))) == "nan"
    assert hash(inf) == hash(AVRational(1, 0))
    assert pickle.loads(pickle.dumps(inf)) == inf


def test_fraction_interop() -> None:
    r = AVRational(1, 2)
    assert r == Fraction(1, 2)
    assert Fraction(1, 2) == r
    assert hash(r) == hash(Fraction(1, 2))
    assert r < Fraction(2, 3) < AVRational(3, 4)
    assert r * Fraction(1, 3) == Fraction(1, 6)
    assert Fraction(1, 3) * r == Fraction(1, 6)
    assert 2 * r == 1
    assert r + 1 == Fraction(3, 2)
    assert 1 - r == Fraction(1, 2)
    assert float(r) == 0.5


def test_avrational_arithmetic() -> None:
    a = AVRational(1, 25)
    b = AVRational(1, 2)
    assert a * b == AVRational(1, 50)
    assert isinstance(a * b, AVRational)
    assert a + b == AVRational(27, 50)
    assert b - a == AVRational(23, 50)
    assert a / b == AVRational(2, 25)
    assert -a == AVRational(-1, 25)
    with pytest.raises(ZeroDivisionError):
        a / AVRational(0, 1)
    huge = AVRational(1, 2**30) * AVRational(1, 2**30)
    assert float(huge) == pytest.approx(2.0**-60, rel=1e-6)


def test_setters_accept_avrational() -> None:
    import av

    cc = av.codec.CodecContext.create("mpeg4", "w")
    cc.time_base = AVRational(1001, 30000)  # type: ignore[assignment]
    assert cc.time_base == Fraction(1001, 30000)


def test_codec_frame_rates() -> None:
    import av

    rates = av.Codec("mpeg2video", "w").frame_rates
    assert rates and all(isinstance(r, AVRational) for r in rates)
    assert AVRational(30000, 1001) in rates


def test_pickle_and_repr() -> None:
    r = AVRational(30000, 1001)
    assert pickle.loads(pickle.dumps(r)) == r
    assert repr(r) == "AVRational(30000, 1001)"
    assert str(r) == "30000/1001"
