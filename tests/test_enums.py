import pickle

from av.enum import EnumType, define_enum

from .common import TestCase

# This must be at the top-level.
PickleableFooBar = define_enum("PickleableFooBar", __name__, [("FOO", 1)])


class TestEnums(TestCase):
    def define_foobar(self, **kwargs):
        return define_enum("Foobar", __name__, (("FOO", 1), ("BAR", 2)), **kwargs)

    def test_basics(self):
        cls = self.define_foobar()

        assert isinstance(cls, EnumType)

        foo = cls.FOO

        assert isinstance(foo, cls)
        assert foo.name == "FOO" and foo.value == 1
        assert not isinstance(foo, PickleableFooBar)

    def test_access(self):
        cls = self.define_foobar()
        foo1 = cls.FOO
        foo2 = cls["FOO"]
        foo3 = cls[1]
        foo4 = cls[foo1]
        assert foo1 is foo2
        assert foo1 is foo3
        assert foo1 is foo4

        assert foo1 in cls
        assert "FOO" in cls
        assert 1 in cls

        self.assertRaises(KeyError, lambda: cls["not a foo"])
        self.assertRaises(KeyError, lambda: cls[10])
        self.assertRaises(TypeError, lambda: cls[()])

        self.assertEqual(cls.get("FOO"), foo1)
        assert cls.get("not a foo") is None

    def test_casting(self):
        cls = self.define_foobar()
        foo = cls.FOO

        self.assertEqual(repr(foo), "<tests.test_enums.Foobar:FOO(0x1)>")

        str_foo = str(foo)
        assert isinstance(str_foo, str)
        assert str_foo == "FOO"

        int_foo = int(foo)
        assert isinstance(int_foo, int)
        assert int_foo == 1

    def test_iteration(self):
        cls = self.define_foobar()
        self.assertEqual(list(cls), [cls.FOO, cls.BAR])

    def test_equality(self):
        cls = self.define_foobar()
        foo = cls.FOO
        bar = cls.BAR

        self.assertEqual(foo, "FOO")
        self.assertEqual(foo, 1)
        self.assertEqual(foo, foo)
        self.assertNotEqual(foo, "BAR")
        self.assertNotEqual(foo, 2)
        self.assertNotEqual(foo, bar)

        self.assertRaises(ValueError, lambda: foo == "not a foo")
        self.assertRaises(ValueError, lambda: foo == 10)
        self.assertRaises(TypeError, lambda: foo == ())

    def test_as_key(self):
        cls = self.define_foobar()
        foo = cls.FOO

        d = {foo: "value"}
        self.assertEqual(d[foo], "value")
        assert d.get("FOO") is None
        assert d.get(1) is None

    def test_pickleable(self):
        cls = PickleableFooBar
        foo = cls.FOO

        enc = pickle.dumps(foo)

        foo2 = pickle.loads(enc)

        assert foo is foo2

    def test_create_unknown(self):
        cls = self.define_foobar()
        baz = cls.get(3, create=True)

        self.assertEqual(baz.name, "FOOBAR_3")
        self.assertEqual(baz.value, 3)

    def test_multiple_names(self):
        cls = define_enum(
            "FFooBBar",
            __name__,
            (
                ("FOO", 1),
                ("F", 1),
                ("BAR", 2),
                ("B", 2),
            ),
        )

        assert cls.F is cls.FOO

        self.assertEqual(cls.F.name, "FOO")
        self.assertNotEqual(cls.F.name, "F")  # This is actually the string.

        self.assertEqual(cls.F, "FOO")
        self.assertEqual(cls.F, "F")
        self.assertNotEqual(cls.F, "BAR")
        self.assertNotEqual(cls.F, "B")
        self.assertRaises(ValueError, lambda: cls.F == "x")

    def test_flag_basics(self):
        cls = define_enum(
            "FoobarAllFlags",
            __name__,
            dict(FOO=1, BAR=2, FOOBAR=3).items(),
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

    def test_multi_flags_basics(self):
        cls = self.define_foobar(is_flags=True)

        foo = cls.FOO
        bar = cls.BAR
        foobar = foo | bar
        self.assertEqual(foobar.name, "FOO|BAR")
        self.assertEqual(foobar.value, 3)
        self.assertEqual(foobar.flags, (foo, bar))

        foobar2 = foo | bar
        foobar3 = cls[3]
        foobar4 = cls[foobar]

        assert foobar is foobar2
        assert foobar is foobar3
        assert foobar is foobar4

        self.assertRaises(KeyError, lambda: cls["FOO|BAR"])

        self.assertEqual(len(cls), 2)  # It didn't get bigger
        self.assertEqual(list(cls), [foo, bar])

    def test_multi_flags_create_missing(self):
        cls = self.define_foobar(is_flags=True)

        foobar = cls[3]
        assert foobar is cls.FOO | cls.BAR

        self.assertRaises(KeyError, lambda: cls[4])  # Not FOO or BAR
        self.assertRaises(KeyError, lambda: cls[7])  # FOO and BAR and missing flag.

    def test_properties(self):
        Flags = self.define_foobar(is_flags=True)
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
        self.assertTrue(obj.foo)
        self.assertFalse(obj.bar)

        obj.bar = True
        assert obj.flags is foobar
        self.assertTrue(obj.foo)
        self.assertTrue(obj.bar)

        obj.foo = False
        assert obj.flags is Flags.BAR
        self.assertFalse(obj.foo)
        self.assertTrue(obj.bar)
