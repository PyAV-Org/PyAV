from fractions import Fraction

class Frame:
    dts: int | None
    pts: int | None
    time: float | None
    time_base: Fraction
    is_corrupt: bool
    side_data: dict[str, str]

    def make_writable(self) -> None: ...
