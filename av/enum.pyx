"""

PyAV provides enumeration and flag classes that are similar to the stdlib ``enum``
module that shipped with Python 3.4.

PyAV's enums are a little more forgiving to preserve backwards compatibility
with earlier PyAV patterns. e.g., they can be freely compared to strings or
integers for names and values respectively.

"""

import copyreg


cdef sentinel = object()


class EnumType(type):
    def __new__(mcl, name, bases, attrs, *args):
        # Just adapting the method signature.
        return super().__new__(mcl, name, bases, attrs)

    def __init__(self, name, bases, attrs, items):
        self._by_name = {}
        self._by_value = {}
        self._all = []

        for spec in items:
            self._create(*spec)

    def _create(self, name, value, doc=None, by_value_only=False):
        # We only have one instance per value.
        try:
            item = self._by_value[value]
        except KeyError:
            item = self(sentinel, name, value, doc)
            self._by_value[value] = item

        if not by_value_only:
            setattr(self, name, item)
            self._all.append(item)
            self._by_name[name] = item

        return item

    def __len__(self):
        return len(self._all)

    def __iter__(self):
        return iter(self._all)

    def __getitem__(self, key):
        if isinstance(key, str):
            return self._by_name[key]

        if isinstance(key, int):
            try:
                return self._by_value[key]
            except KeyError:
                pass

            if issubclass(self, EnumFlag):
                return self._get_multi_flags(key)

            raise KeyError(key)

        if isinstance(key, self):
            return key

        raise TypeError(f"{self.__name__} indices must be str, int, or itself")

    def _get(self, long value, bint create=False):
        try:
            return self._by_value[value]
        except KeyError:
            pass

        if not create:
            return

        return self._create(f"{self.__name__.upper()}_{value}", value, by_value_only=True)

    def _get_multi_flags(self, long value):
        try:
            return self._by_value[value]
        except KeyError:
            pass

        flags = []
        cdef long to_find = value
        for item in self:
            if item.value & to_find:
                flags.append(item)
                to_find = to_find ^ item.value
                if not to_find:
                    break

        if to_find:
            raise KeyError(value)

        name = "|".join(f.name for f in flags)
        cdef EnumFlag combo = self._create(name, value, by_value_only=True)
        combo.flags = tuple(flags)

        return combo

    def get(self, key, default=None, create=False):
        try:
            return self[key]
        except KeyError:
            if create:
                return self._get(key, create=True)
            return default

    def property(self, *args, **kwargs):
        return EnumProperty(self, *args, **kwargs)


def _unpickle(mod_name, cls_name, item_name):
    mod = __import__(mod_name, fromlist=["."])
    cls = getattr(mod, cls_name)
    return cls[item_name]


copyreg.constructor(_unpickle)


cdef class EnumItem:
    cdef readonly str name
    cdef readonly int value
    cdef Py_hash_t _hash

    def __cinit__(self, sentinel_, str name, int value, doc=None):
        if sentinel_ is not sentinel:
            raise RuntimeError(f"Cannot instantiate {self.__class__.__name__}.")

        self.name = name
        self.value = value
        self.__doc__ = doc

        # We need to establish a hash that doesn't collide with anything that
        # would return true from `__eq__`. This is because these enums (vs
        # the stdlib ones) are weakly typed (they will compare against string
        # names and int values), and if we have the same hash AND are equal,
        # then they will be equivalent as keys in a dictionary, which is wierd.
        cdef Py_hash_t hash_ = value + 1
        if hash_ == hash(name):
            hash_ += 1
        self._hash = hash_

    def __repr__(self):
        return f"<{self.__class__.__module__}.{self.__class__.__name__}:{self.name}(0x{self.value:x})>"

    def __str__(self):
        return self.name

    def __int__(self):
        return self.value

    def __hash__(self):
        return self._hash

    def __reduce__(self):
        return (_unpickle, (self.__class__.__module__, self.__class__.__name__, self.name))

    def __eq__(self, other):
        if isinstance(other, str):
            if self.name == other:
                return True

            try:
                other_inst = self.__class__._by_name[other]
            except KeyError:
                raise ValueError(
                    f"{self.__class__.__name__} does not have item named {other!r}"
                )
            else:
                return self is other_inst

        if isinstance(other, int):
            if self.value == other:
                return True
            if other in self.__class__._by_value:
                return False
            raise ValueError(
                f"{self.__class__.__name__} does not have item valued {other}"
            )

        if isinstance(other, self.__class__):
            return self is other

        raise TypeError(
            f"'==' not supported between {self.__class__.__name__} and {type(other).__name__}"
        )

    def __ne__(self, other):
        return not (self == other)


cdef class EnumFlag(EnumItem):

    """
    Flags are sets of boolean attributes, which the FFmpeg API represents as individual
    bits in a larger integer which you manipulate with the bitwise operators.
    We associate names with each flag that are easier to operate with.

    Consider :data:`CodecContextFlags`, whis is the type of the :attr:`CodecContext.flags`
    attribute, and the set of boolean properties::

        >>> fh = av.open(video_path)
        >>> cc = fh.streams.video[0].codec_context

        >>> cc.flags
        <av.codec.context.Flags:NONE(0x0)>

        >>> # You can set flags via bitwise operations with the objects, names, or values:
        >>> cc.flags |= cc.flags.OUTPUT_CORRUPT
        >>> cc.flags |= 'GLOBAL_HEADER'
        >>> cc.flags
        <av.codec.context.Flags:OUTPUT_CORRUPT|GLOBAL_HEADER(0x400008)>

        >>> # You can test flags via bitwise operations with objects, names, or values:
        >>> bool(cc.flags & cc.flags.OUTPUT_CORRUPT)
        True
        >>> bool(cc.flags & 'QSCALE')
        False

        >>> # There are boolean properties for each flag:
        >>> cc.output_corrupt
        True
        >>> cc.qscale
        False

        >>> # You can set them:
        >>> cc.qscale = True
        >>> cc.flags
        <av.codec.context.Flags:QSCALE|OUTPUT_CORRUPT|GLOBAL_HEADER(0x40000a)>

    """

    cdef readonly tuple flags

    def __cinit__(self, sentinel, name, value, doc=None):
        self.flags = (self, )

    def __and__(self, other):
        if not isinstance(other, int):
            other = self.__class__[other].value
        value = self.value & other
        return self.__class__._get_multi_flags(value)

    def __or__(self, other):
        if not isinstance(other, int):
            other = self.__class__[other].value
        value = self.value | other
        return self.__class__._get_multi_flags(value)

    def __xor__(self, other):
        if not isinstance(other, int):
            other = self.__class__[other].value
        value = self.value ^ other
        return self.__class__._get_multi_flags(value)

    def __invert__(self):
        # This can't result in a flag, but is helpful.
        return ~self.value

    def __nonzero__(self):
        return bool(self.value)


cdef class EnumProperty:
    cdef object enum
    cdef object fget
    cdef object fset
    cdef public __doc__

    def __init__(self, enum, fget, fset=None, doc=None):
        self.enum = enum
        self.fget = fget
        self.fset = fset
        self.__doc__ = doc or fget.__doc__

    def setter(self, fset):
        self.fset = fset
        return self

    def __get__(self, inst, owner):
        if inst is not None:
            value = self.fget(inst)
            return self.enum.get(value, create=True)
        else:
            return self

    def __set__(self, inst, value):
        item = self.enum.get(value)
        self.fset(inst, item.value)

    def flag_property(self, name, doc=None):

        item = self.enum[name]
        cdef int item_value = item.value

        class Property(property):
            pass

        @Property
        def _property(inst):
            return bool(self.fget(inst) & item_value)

        if self.fset:
            @_property.setter
            def _property(inst, value):
                if value:
                    flags = self.fget(inst) | item_value
                else:
                    flags = self.fget(inst) & ~item_value
                self.fset(inst, flags)

        _property.__doc__ = doc or item.__doc__
        _property._enum_item = item

        return _property


cpdef define_enum(name, module, items, bint is_flags=False):

    if is_flags:
        base_cls = EnumFlag
    else:
        base_cls = EnumItem

    # Some items may be None if they correspond to an unsupported FFmpeg feature
    cls = EnumType(name, (base_cls, ), {"__module__": module}, [i for i in items if i is not None])

    return cls
