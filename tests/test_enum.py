import pickle

from .common import *

from av.enums import *


# This must be at the top-level.
PickleableFooBar = define_enum('PickleableFooBar', dict(FOO=1))


class TestEnums(TestCase):

    def define_foobar(self, **kwargs):
        return define_enum('Foobar', dict(
            FOO=1,
            BAR=2,
        ), **kwargs)

    def test_basics(self):

        cls = self.define_foobar()

        self.assertIsInstance(cls, EnumType)

        foo = cls.FOO

        self.assertIsInstance(foo, cls)
        self.assertEqual(foo.name, 'FOO')
        self.assertEqual(foo.value, 1)

    def test_access(self):

        cls = self.define_foobar()
        foo1 = cls.FOO
        foo2 = cls['FOO']
        foo3 = cls[1]
        foo4 = cls[foo1]
        self.assertIs(foo1, foo2)
        self.assertIs(foo1, foo3)
        self.assertIs(foo1, foo4)

        self.assertRaises(KeyError, lambda: cls['not a foo'])
        self.assertRaises(KeyError, lambda: cls[10])
        self.assertRaises(TypeError, lambda: cls[{}])

        self.assertEqual(cls.get('FOO'), foo1)
        self.assertIs(cls.get('not a foo'), None)


    def test_casting(self):

        cls = self.define_foobar()
        foo = cls.FOO

        self.assertEqual(repr(foo), '<Foobar:FOO(1)>')

        str_foo = str(foo)
        self.assertIsInstance(str_foo, str)
        self.assertEqual(str_foo, 'FOO')

        int_foo = int(foo)
        self.assertIsInstance(int_foo, int)
        self.assertEqual(int_foo, 1)


    def test_iteration(self):
        cls = self.define_foobar()
        self.assertEqual(list(cls), [cls.FOO, cls.BAR])

    def test_equality(self):

        cls = self.define_foobar()
        foo = cls.FOO
        bar = cls.BAR

        self.assertEqual(foo, 'FOO')
        self.assertEqual(foo, 1)
        self.assertEqual(foo, foo)
        self.assertNotEqual(foo, 'BAR')
        self.assertNotEqual(foo, 2)
        self.assertNotEqual(foo, bar)

        self.assertRaises(ValueError, lambda: foo == 'not a foo')
        self.assertRaises(ValueError, lambda: foo == 10)
        self.assertRaises(TypeError, lambda: foo == {})

    def test_as_key(self):

        cls = self.define_foobar()
        foo = cls.FOO

        d = {foo: 'value'}
        self.assertEqual(d[foo], 'value')
        self.assertIs(d.get('FOO'), None)
        self.assertIs(d.get(1), None)

    def test_pickleable(self):

        cls = PickleableFooBar
        foo = cls.FOO

        enc = pickle.dumps(foo)
        print(enc)

        foo2 = pickle.loads(enc)

        self.assertIs(foo, foo2)

    def test_flag_basics(self):

        cls = define_enum('FoobarAllFlags', dict(FOO=1, BAR=2, FOOBAR=3), flags=True)
        foo = cls.FOO
        bar = cls.BAR

        foobar = foo | bar
        self.assertIs(foobar, cls.FOOBAR)

        foo2 = foobar & foo
        self.assertIs(foo2, foo)

        bar2 = foobar ^ foo
        self.assertIs(bar2, bar)

    def test_flag_combos_basics(self):

        cls = define_enum('FoobarMissingFlags', dict(FOO=1, BAR=2), flags=True)
        self.assertRaises(ValueError, lambda: cls.FOO | cls.BAR)

        cls = define_enum('FoobarComboFlags', dict(FOO=1, BAR=2), flags=True, allow_combo=True)

        foobar = cls.FOO | cls.BAR
        self.assertEqual(foobar.name, 'FOO|BAR')
        self.assertEqual(foobar.value, 3)

        foobar2 = cls.FOO | cls.BAR
        foobar3 = cls[3]
        foobar4 = cls[foobar]

        self.assertIs(foobar, foobar2)
        self.assertIs(foobar, foobar3)
        self.assertIs(foobar, foobar4)

        self.assertRaises(KeyError, lambda: cls['FOO|BAR'])

        self.assertEqual(len(cls), 2) # It didn't get bigger
        self.assertEqual(list(cls), [cls.FOO, cls.BAR])


    def test_flag_combo_lookup_create(self):

        cls = define_enum('FoobarComboFlags', dict(FOO=1, BAR=2), flags=True, allow_combo=True)

        foobar = cls[3]
        self.assertIs(foobar, cls.FOO | cls.BAR)

        self.assertRaises(KeyError, lambda: cls[4]) # Not FOO or BAR
        self.assertRaises(KeyError, lambda: cls[7]) # FOO and BAR and missing flag.











