# type: ignore
from fractions import Fraction
from numbers import Rational

import cython
from cython.cimports import libav as lib

_INT32_MAX: cython.longlong = 2147483647


@cython.cclass
class AVRational:
    """
    An exact rational number stored as two int32s, mirroring FFmpeg's
    ``AVRational``.

    Values are always reduced to lowest terms with a positive denominator.
    Arithmetic between two :class:`AVRational` uses FFmpeg's ``av_mul_q``
    family: intermediates are computed in int64, then reduced back to int32,
    **approximating** the result if it does not fit. Arithmetic with other
    numeric types promotes to :class:`fractions.Fraction` (exact).

    Following FFmpeg, a zero denominator is allowed: ``1/0``, ``-1/0``
    (infinities) and ``0/0`` (undefined) exist and, like the unset value
    ``AVRational(0, 1)``, are falsy — so ``if rate:`` covers every
    not-a-real-value case that used to be ``None``.

    Every PyAV setter that accepts a :class:`fractions.Fraction` (e.g.
    ``stream.time_base``, ``codec_context.framerate``) also accepts an
    :class:`AVRational`.
    """

    def __init__(self, num=0, den=1):
        if den == 1 and isinstance(num, Rational):
            num, den = num.numerator, num.denominator
        n64: cython.longlong = num
        d64: cython.longlong = den
        n: cython.int
        d: cython.int
        if not lib.av_reduce(
            cython.address(n), cython.address(d), n64, d64, _INT32_MAX
        ):
            raise OverflowError(f"{num}/{den} cannot be reduced to fit in int32")
        self.num = n
        self.den = d

    @cython.cfunc
    def _q(self) -> lib.AVRational:
        q: lib.AVRational
        q.num = self.num
        q.den = self.den
        return q

    @property
    def numerator(self):
        return self.num

    @property
    def denominator(self):
        return self.den

    def __repr__(self):
        return f"AVRational({self.num}, {self.den})"

    def __str__(self):
        return f"{self.num}/{self.den}"

    def __bool__(self):
        return self.num != 0 and self.den != 0

    def __float__(self):
        if self.den == 0:
            return float("nan") if self.num == 0 else self.num * float("inf")
        return self.num / self.den

    def __hash__(self):
        if self.den == 0:
            return hash((self.num, 0))
        return hash(Fraction(self.num, self.den))

    def __reduce__(self):
        return (AVRational, (self.num, self.den))

    def __eq__(self, other):
        if isinstance(other, AVRational):
            o: AVRational = other
            return self.num == o.num and self.den == o.den
        if self.den == 0:
            return False
        return Fraction(self.num, self.den) == other

    def __lt__(self, other):
        return Fraction(self.num, self.den) < other

    def __le__(self, other):
        return Fraction(self.num, self.den) <= other

    def __gt__(self, other):
        return Fraction(self.num, self.den) > other

    def __ge__(self, other):
        return Fraction(self.num, self.den) >= other

    def __neg__(self):
        return AVRational(-self.num, self.den)

    def __mul__(self, other):
        if isinstance(other, AVRational):
            o: AVRational = other
            return from_avrational(lib.av_mul_q(self._q(), o._q()))
        return Fraction(self.num, self.den) * other

    def __rmul__(self, other):
        return other * Fraction(self.num, self.den)

    def __truediv__(self, other):
        if isinstance(other, AVRational):
            o: AVRational = other
            if o.num == 0:
                raise ZeroDivisionError(f"{self} / {other}")
            return from_avrational(lib.av_div_q(self._q(), o._q()))
        return Fraction(self.num, self.den) / other

    def __rtruediv__(self, other):
        return other / Fraction(self.num, self.den)

    def __add__(self, other):
        if isinstance(other, AVRational):
            o: AVRational = other
            return from_avrational(lib.av_add_q(self._q(), o._q()))
        return Fraction(self.num, self.den) + other

    def __radd__(self, other):
        return other + Fraction(self.num, self.den)

    def __sub__(self, other):
        if isinstance(other, AVRational):
            o: AVRational = other
            return from_avrational(lib.av_sub_q(self._q(), o._q()))
        return Fraction(self.num, self.den) - other

    def __rsub__(self, other):
        return other - Fraction(self.num, self.den)


@cython.cfunc
def from_avrational(q: lib.AVRational) -> AVRational:
    obj: AVRational = AVRational.__new__(AVRational)
    # FFmpeg does not guarantee reduced form; our invariant requires it.
    lib.av_reduce(
        cython.address(obj.num), cython.address(obj.den), q.num, q.den, _INT32_MAX
    )
    return obj


Rational.register(AVRational)
