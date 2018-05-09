
try:
    import copyreg
except ImportError:
    import copy_reg as copyreg


cdef sentinel = object()


cdef class EnumType(type):

    cdef readonly str name
    cdef readonly tuple names
    cdef readonly tuple values

    cdef readonly bint flags
    cdef readonly bint allow_combo

    cdef _by_name
    cdef _by_value
    cdef _all

    cdef _get_combo(self, long value):

        try:
            return self._by_value[value]
        except KeyError:
            pass

        if not self.allow_combo:
            raise ValueError("Missing flag in {}.".format(self.__name__), value)

        flags = []
        cdef long to_find = value
        for item in self:
            if item.value & to_find:
                flags.append(item)
                to_find = to_find ^ item.value
                if not to_find:
                    break
        if to_find:
            raise ValueError("Could not build combo in {}.".format(self.__name__, value))

        name = '|'.join(f.name for f in flags)
        cdef EnumFlag combo = self(sentinel, name, value)
        combo.flags = tuple(flags)
        self._by_value[value] = combo

        return combo

    def __len__(self):
        return len(self._all)

    def __iter__(self):
        return iter(self._all)

    def __getitem__(self, key):
        if isinstance(key, basestring):
            return self._by_name[key]
        if isinstance(key, int):
            try:
                return self._by_value[key]
            except KeyError:
                if not self.allow_combo:
                    raise
                try:
                    return self._get_combo(key)
                except ValueError:
                    raise KeyError(key)
        if isinstance(key, self):
            return key
        raise TypeError("Uncomparable to {}.".format(self.name), key)

    def get(self, key, default=None):
        try:
            return self[key]
        except KeyError:
            return default


def _unpickle(mod_name, cls_name, item_name):
    mod = __import__(mod_name, fromlist=['.'])
    cls = getattr(mod, cls_name)
    return cls[item_name]
copyreg.constructor(_unpickle)


cdef class EnumItem(object):

    cdef readonly str name
    cdef readonly int value
    cdef long _hash

    def __cinit__(self, sentinel_, name, value):

        if sentinel_ is not sentinel:
            raise RuntimeError("Cannot instantiate {}.".format(self.__class__.__name__))
        self.name = name
        self.value = value

        # Establish a hash that doesn't collide with anything that would return
        # true from __eq__.
        hash_ = id(self)
        name_hash = hash(name)
        value_hash = hash(value)
        while hash_ == name_hash or hash_ == value_hash:
            hash_ += 1
        self._hash = hash_

    def __repr__(self):
        return '<{}:{}({})>'.format(self.__class__.__name__, self.name, self.value)

    def __str__(self):
        return self.name

    def __int__(self):
        return self.value

    def __hash__(self):
        return self._hash

    def __reduce__(self):
        return (_unpickle, (self.__class__.__module__, self.__class__.__name__, self.name))

    def __eq__(self, other):

        if isinstance(other, basestring):
            if self.name == other:
                return True
            if other in (<EnumType>self.__class__)._by_name:
                return False
            raise ValueError("Name not in {}.".format(self.__class__.__name__), other)

        if isinstance(other, int):
            if self.value == other:
                return True
            if other in (<EnumType>self.__class__)._by_value:
                return False
            raise ValueError("Value not in {}.".format(self.__class__.__name__), other)

        if isinstance(other, self.__class__):
            return self is other

        raise TypeError("Uncomparable to {}.".format(self.__class__.__name__), other)

    def __ne__(self, other):
        return not (self == other)


cdef class EnumFlag(EnumItem):

    cdef readonly tuple flags

    def __cinit__(self, sentinel, name, value):
        self.flags = (self, )

    def __and__(self, other):
        other = self.__class__[other]
        value = self.value & other.value
        return (<EnumType>self.__class__)._get_combo(value)

    def __or__(self, other):
        other = self.__class__[other]
        value = self.value | other.value
        return (<EnumType>self.__class__)._get_combo(value)

    def __xor__(self, other):
        other = self.__class__[other]
        value = self.value ^ other.value
        return (<EnumType>self.__class__)._get_combo(value)


def define_enum(name, items, flags=False, allow_combo=False):

    if isinstance(items, dict):
        items = list(items.items())
    else:
        items = list(items)

    if flags:
        base_cls = EnumFlag
    else:
        base_cls = EnumItem

    cls = EnumType(name, (base_cls, ), {})
    cls.name = name
    cls.flags = bool(flags)
    cls.allow_combo = bool(allow_combo)

    cls._by_name = by_name = {}
    cls._by_value = by_value = {}
    cls._all = all_ = []

    names = []
    values = []

    for name, value in items:

        names.append(name)
        values.append(value)

        item = cls(sentinel, name, value)

        setattr(cls, name, item)
        all_.append(item)
        by_name[name] = item
        by_value[value] = item

    cls.names = tuple(names)
    cls.values = tuple(values)

    return cls

