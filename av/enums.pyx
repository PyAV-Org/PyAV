
try:
    import copyreg
except ImportError:
    import copy_reg as copyreg


cdef sentinel = object()


cdef class EnumType(type):

    cdef readonly str name
    cdef readonly tuple names
    cdef readonly tuple values

    cdef _by_name
    cdef _by_value
    cdef _all

    def __iter__(self):
        return iter(self._all)

    def __getitem__(self, key):
        if isinstance(key, basestring):
            return self._by_name[key]
        if isinstance(key, int):
            return self._by_value[key]
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




def define_enum(name, items):

    if isinstance(items, dict):
        items = list(items.items())
    else:
        items = list(items)

    cls = EnumType(name, (EnumItem, ), {})
    cls.name = name

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

