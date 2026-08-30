import pickle
from decimal import Decimal
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
    cc.time_base = AVRational(1001, 30000)
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


def test_nonfinite_equality() -> None:
    inf, nan = float("inf"), float("nan")

    # Equality between two AVRationals is structural.
    assert AVRational(1, 0) == AVRational(2, 0)
    assert AVRational(0, 0) == AVRational(0, 0)
    assert AVRational(1, 0) != AVRational(-1, 0)
    assert AVRational(1, 0) != AVRational(0, 0)

    # Against another numeric type it is by value, so the hashes must agree.
    assert AVRational(1, 0) == inf and hash(AVRational(1, 0)) == hash(inf)
    assert AVRational(-1, 0) == -inf and hash(AVRational(-1, 0)) == hash(-inf)
    assert AVRational(1, 0) == Decimal("Infinity")
    assert hash(AVRational(1, 0)) == hash(Decimal("Infinity"))
    assert {AVRational(1, 0)} == {inf}

    # 0/0 equals no value of another type, not even a NaN.
    assert AVRational(0, 0) != nan
    assert AVRational(0, 0) != Decimal("NaN")
    assert AVRational(0, 0) != 0 and AVRational(0, 0) != Fraction(0, 1)

    assert AVRational(1, 0) != "x" and AVRational(1, 0) is not None


def test_nonfinite_ordering() -> None:
    inf = float("inf")
    neg, pos, undef, half = (
        AVRational(-1, 0),
        AVRational(1, 0),
        AVRational(0, 0),
        AVRational(1, 2),
    )

    assert neg < half < pos < undef
    assert undef > pos > half > neg
    assert not (pos < pos) and pos <= pos and pos >= pos
    assert not (undef < undef) and undef <= undef and undef >= undef

    # A finite AVRational against a non-finite one, either way round.
    assert half < pos and pos > half
    assert half > neg and neg < half
    assert not (half >= pos) and not (pos <= half)

    # Against plain numbers, including infinities of another type.
    assert pos > 10**9 and pos > 1e308 and pos > Fraction(10**9)
    assert neg < -(10**9) and neg < -1e308
    assert pos <= inf and pos >= inf and not (pos < inf) and not (pos > inf)
    assert neg <= -inf and neg >= -inf
    assert half < inf and half > -inf
    assert undef > inf and undef > 0 and not (undef < inf)


def test_nonfinite_ordering_is_consistent() -> None:
    values = [
        AVRational(0, 0),
        AVRational(1, 0),
        AVRational(-1, 0),
        AVRational(1, 2),
        AVRational(0, 1),
        Fraction(1, 2),
        0,
        7,
        -2.5,
        float("inf"),
        float("-inf"),
        Decimal("0.5"),
        Decimal("Infinity"),
    ]
    for a in (v for v in values if isinstance(v, AVRational)):
        for b in values:
            eq, lt, le, gt, ge = a == b, a < b, a <= b, a > b, a >= b
            assert le == (lt or eq), (a, b)
            assert ge == (gt or eq), (a, b)
            assert not (lt and gt), (a, b)
            if isinstance(b, AVRational):
                assert (lt, le, eq) == (b > a, b >= a, b == a), (a, b)
                assert lt + eq + gt == 1, (a, b)
            if eq:
                assert hash(a) == hash(b), (a, b)


def test_nan_is_unordered() -> None:
    rationals = (AVRational(1, 2), AVRational(1, 0), AVRational(0, 0))
    for value in (float("nan"), Decimal("NaN"), Decimal("sNaN")):
        for r in rationals:
            assert not (r < value) and not (r <= value)
            assert not (r > value) and not (r >= value)

    for value in (float("nan"), Decimal("NaN")):
        for r in rationals:
            assert r != value


def test_nonfinite_sorting() -> None:
    values = [
        AVRational(1, 0),
        AVRational(0, 0),
        AVRational(1, 2),
        AVRational(-1, 0),
        AVRational(3, 1),
        AVRational(-3, 1),
    ]
    expected = [
        AVRational(-1, 0),
        AVRational(-3, 1),
        AVRational(1, 2),
        AVRational(3, 1),
        AVRational(1, 0),
        AVRational(0, 0),
    ]
    assert sorted(values) == expected
    backwards = values[::-1]
    assert sorted(backwards) == expected
    assert max(values) == AVRational(0, 0)
    assert min(values) == AVRational(-1, 0)


def test_unorderable_types() -> None:
    for value in ("x", None, 1j, object()):
        for r in (AVRational(1, 2), AVRational(1, 0), AVRational(0, 0)):
            with pytest.raises(TypeError):
                r < value  # noqa: B015
            with pytest.raises(TypeError):
                r >= value  # noqa: B015


def test_fraction_on_the_left_is_asymmetric() -> None:
    assert Fraction(1, 2) < AVRational(1, 0)
    assert Fraction(1, 2) > AVRational(-1, 0)
    assert Fraction(1, 2) >= AVRational(0, 0)
    assert not (AVRational(0, 0) <= Fraction(1, 2))
    assert not (Fraction(1, 2) < AVRational(0, 0))
    assert AVRational(0, 0) > Fraction(1, 2)
