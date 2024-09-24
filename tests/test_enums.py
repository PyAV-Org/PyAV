import pickle

import pytest

from av.enum import EnumType, define_enum

PickleableFooBar = define_enum("PickleableFooBar", __name__, [("FOO", 1)])


def define_foobar(is_flags: bool = False):
    return define_enum("Foobar", __name__, (("FOO", 1), ("BAR", 2)), is_flags=is_flags)


def test_basics():
    cls = define_foobar()

    assert isinstance(cls, EnumType)

    foo = cls.FOO

    assert isinstance(foo, cls)
    assert foo.name == "FOO" and foo.value == 1
    assert not isinstance(foo, PickleableFooBar)


def test_access():
    cls = define_foobar()
    foo1 = cls.FOO
    foo2 = cls["FOO"]
    foo3 = cls[1]
    foo4 = cls[foo1]
    assert foo1 is foo2
    assert foo1 is foo3
    assert foo1 is foo4

    assert foo1 in cls and "FOO" in cls and 1 in cls

    pytest.raises(KeyError, lambda: cls["not a foo"])
    pytest.raises(KeyError, lambda: cls[10])
    pytest.raises(TypeError, lambda: cls[()])

    assert cls.get("FOO") == foo1
    assert cls.get("not a foo") is None


def test_casting():
    cls = define_foobar()
    foo = cls.FOO

    assert repr(foo) == "<tests.test_enums.Foobar:FOO(0x1)>"

    str_foo = str(foo)
    assert isinstance(str_foo, str) and str_foo == "FOO"

    int_foo = int(foo)
    assert isinstance(int_foo, int) and int_foo == 1


def test_iteration():
    cls = define_foobar()
    assert list(cls) == [cls.FOO, cls.BAR]


def test_equality():
    cls = define_foobar()
    foo = cls.FOO
    bar = cls.BAR

    assert foo == "FOO" and foo == 1 and foo == foo
    assert foo != "BAR" and foo != 2 and foo != bar

    pytest.raises(ValueError, lambda: foo == "not a foo")
    pytest.raises(ValueError, lambda: foo == 10)
    pytest.raises(TypeError, lambda: foo == ())


def test_as_key():
    cls = define_foobar()
    foo = cls.FOO

    d = {foo: "value"}
    assert d[foo] == "value"
    assert d.get("FOO") is None
    assert d.get(1) is None


def test_pickleable():
    cls = PickleableFooBar
    foo = cls.FOO

    enc = pickle.dumps(foo)

    foo2 = pickle.loads(enc)

    assert foo is foo2


def test_create_unknown():
    cls = define_foobar()
    baz = cls.get(3, create=True)

    assert baz.name == "FOOBAR_3"
    assert baz.value == 3


def test_multiple_names():
    cls = define_enum(
        "FFooBBar",
        __name__,
        (("FOO", 1), ("F", 1), ("BAR", 2), ("B", 2)),
    )

    assert cls.F is cls.FOO

    assert cls.F.name == "FOO"
    assert cls.F.name != "F"  # This is actually the string.

    assert cls.F == "FOO"
    assert cls.F == "F"
    assert cls.F != "BAR"
    assert cls.F != "B"
    pytest.raises(ValueError, lambda: cls.F == "x")


def test_flag_basics():
    cls = define_enum(
        "FoobarAllFlags",
        __name__,
        {"FOO": 1, "BAR": 2, "FOOBAR": 3}.items(),
        is_flags=True,
    )
    foo = cls.FOO
    bar = cls.BAR

    foobar = foo | bar
    assert foobar is cls.FOOBAR

    foo2 = foobar & foo
    assert foo2 is foo

    bar2 = foobar ^ foo
    assert bar2 is bar

    bar3 = foobar & ~foo
    assert bar3 is bar

    x = cls.FOO
    x |= cls.BAR
    assert x is cls.FOOBAR

    x = cls.FOOBAR
    x &= cls.FOO
    assert x is cls.FOO


def test_multi_flags_basics():
    cls = define_foobar(is_flags=True)

    foo = cls.FOO
    bar = cls.BAR
    foobar = foo | bar
    assert foobar.name == "FOO|BAR"
    assert foobar.value == 3
    assert foobar.flags == (foo, bar)

    foobar2 = foo | bar
    foobar3 = cls[3]
    foobar4 = cls[foobar]

    assert foobar is foobar2
    assert foobar is foobar3
    assert foobar is foobar4

    pytest.raises(KeyError, lambda: cls["FOO|BAR"])

    assert len(cls) == 2  # It didn't get bigger
    assert list(cls) == [foo, bar]


def test_multi_flags_create_missing():
    cls = define_foobar(is_flags=True)

    foobar = cls[3]
    assert foobar is cls.FOO | cls.BAR

    pytest.raises(KeyError, lambda: cls[4])  # Not FOO or BAR
    pytest.raises(KeyError, lambda: cls[7])  # FOO and BAR and missing flag.


def test_properties():
    Flags = define_foobar(is_flags=True)
    foobar = Flags.FOO | Flags.BAR

    class Class:
        def __init__(self, value):
            self.value = Flags[value].value

        @Flags.property
        def flags(self):
            return self.value

        @flags.setter
        def flags(self, value):
            self.value = value

        foo = flags.flag_property("FOO")
        bar = flags.flag_property("BAR")

    obj = Class("FOO")

    assert obj.flags is Flags.FOO
    assert obj.foo
    assert not obj.bar

    obj.bar = True
    assert obj.flags is foobar
    assert obj.foo
    assert obj.bar

    obj.foo = False
    assert obj.flags is Flags.BAR
    assert not obj.foo
    assert obj.bar
