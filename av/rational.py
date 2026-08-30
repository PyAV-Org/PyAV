# type: ignore
import sys
from decimal import Decimal
from fractions import Fraction
from numbers import Rational, Real

import cython
from cython.cimports import libav as lib

_INT32_MAX: cython.longlong = 2147483647
_INF: cython.double = float("inf")
_HASH_INF = sys.hash_info.inf
_C_NEG_INF: cython.int = -1
_C_FINITE: cython.int = 0
_C_POS_INF: cython.int = 1
_C_UNDEF: cython.int = 2
_C_NAN: cython.int = 100  # foreign NaN: unordered, every comparison is False
_C_UNKNOWN: cython.int = 101  # not a real number: NotImplemented

_LT: cython.int = 0
_LE: cython.int = 1
_GT: cython.int = 2
_GE: cython.int = 3


@cython.final
@cython.cclass
class AVRational:
    """
    An exact rational number stored as two int32s, mirroring FFmpeg's
    ``AVRational``. It is a final class and cannot be subclassed.

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
            # ``1/0 == float("inf")``, so the two must hash alike.
            if self.num == 0:
                return hash((0, 0))
            return _HASH_INF if self.num > 0 else -_HASH_INF
        return hash(Fraction(self.num, self.den))

    def __reduce__(self):
        return (AVRational, (self.num, self.den))

    def __eq__(self, other):
        if type(other) is AVRational:
            o: AVRational = other
            return self.num == o.num and self.den == o.den
        if self.den == 0:
            cb: cython.int = _order_class(other)
            if cb == _C_UNKNOWN:
                return NotImplemented
            return _order_class(self) == cb
        return Fraction(self.num, self.den).__eq__(other)

    def __lt__(self, other):
        cb: cython.int = _order_class(other)
        if self.den == 0 or cb != _C_FINITE:
            return _cmp(self, cb, _LT)
        return Fraction(self.num, self.den).__lt__(other)

    def __le__(self, other):
        cb: cython.int = _order_class(other)
        if self.den == 0 or cb != _C_FINITE:
            return _cmp(self, cb, _LE)
        return Fraction(self.num, self.den).__le__(other)

    def __gt__(self, other):
        cb: cython.int = _order_class(other)
        if self.den == 0 or cb != _C_FINITE:
            return _cmp(self, cb, _GT)
        return Fraction(self.num, self.den).__gt__(other)

    def __ge__(self, other):
        cb: cython.int = _order_class(other)
        if self.den == 0 or cb != _C_FINITE:
            return _cmp(self, cb, _GE)
        return Fraction(self.num, self.den).__ge__(other)

    def __neg__(self):
        return AVRational(-self.num, self.den)

    def __mul__(self, other):
        if type(other) is AVRational:
            o: AVRational = other
            return from_avrational(lib.av_mul_q(self._q(), o._q()))
        return Fraction(self.num, self.den).__mul__(other)

    def __rmul__(self, other):
        return Fraction(self.num, self.den).__rmul__(other)

    def __truediv__(self, other):
        if type(other) is AVRational:
            o: AVRational = other
            if o.num == 0:
                raise ZeroDivisionError(f"{self} / {other}")
            return from_avrational(lib.av_div_q(self._q(), o._q()))
        return Fraction(self.num, self.den).__truediv__(other)

    def __rtruediv__(self, other):
        return Fraction(self.num, self.den).__rtruediv__(other)

    def __add__(self, other):
        if type(other) is AVRational:
            o: AVRational = other
            return from_avrational(lib.av_add_q(self._q(), o._q()))
        return Fraction(self.num, self.den).__add__(other)

    def __radd__(self, other):
        return Fraction(self.num, self.den).__radd__(other)

    def __sub__(self, other):
        if type(other) is AVRational:
            o: AVRational = other
            return from_avrational(lib.av_sub_q(self._q(), o._q()))
        return Fraction(self.num, self.den).__sub__(other)

    def __rsub__(self, other):
        return Fraction(self.num, self.den).__rsub__(other)


@cython.cfunc
def _order_class(v) -> cython.int:
    if type(v) is AVRational:
        o: AVRational = v
        if o.den != 0:
            return _C_FINITE
        if o.num == 0:
            return _C_UNDEF
        return _C_POS_INF if o.num > 0 else _C_NEG_INF
    if isinstance(v, Rational):  # int, Fraction, ...
        return _C_FINITE
    if isinstance(v, Decimal):
        if v.is_nan():
            return _C_NAN
        if v.is_infinite():
            return _C_POS_INF if v > 0 else _C_NEG_INF
        return _C_FINITE
    if isinstance(v, Real):  # float, numpy scalars, ...
        f: cython.double = v
        if f != f:
            return _C_NAN
        if f == _INF:
            return _C_POS_INF
        if f == -_INF:
            return _C_NEG_INF
        return _C_FINITE
    return _C_UNKNOWN


# Returns object, not bint: NotImplemented must reach Python intact so the
# reflected operator gets a turn.
@cython.cfunc
def _cmp(a: AVRational, cb: cython.int, op: cython.int):
    if cb == _C_UNKNOWN:
        return NotImplemented
    if cb == _C_NAN:
        return False
    ca: cython.int = _order_class(a)
    if op == _LT:
        return ca < cb
    if op == _LE:
        return ca <= cb
    if op == _GT:
        return ca > cb
    return ca >= cb


@cython.cfunc
def from_avrational(q: lib.AVRational) -> AVRational:
    obj: AVRational = AVRational.__new__(AVRational)
    # FFmpeg does not guarantee reduced form
    lib.av_reduce(
        cython.address(obj.num), cython.address(obj.den), q.num, q.den, _INT32_MAX
    )
    return obj


Rational.register(AVRational)
