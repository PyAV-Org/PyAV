cimport libav as lib

from .option cimport Option, OptionChoice, wrap_option, wrap_option_choice


cdef object _cinit_sentinel = object()

cdef Descriptor wrap_avclass(const lib.AVClass *ptr):
    if ptr == NULL:
        return None
    cdef Descriptor obj = Descriptor(_cinit_sentinel)
    obj.ptr = ptr
    return obj


cdef class Descriptor:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("Cannot construct av.Descriptor")

    @property
    def name(self):
        return self.ptr.class_name if self.ptr.class_name else None

    @property
    def options(self):
        cdef const lib.AVOption *ptr = self.ptr.option
        cdef const lib.AVOption *choice_ptr
        cdef Option option
        cdef OptionChoice option_choice
        cdef bint choice_is_default
        if self._options is None:
            options = []
            ptr = self.ptr.option
            while ptr != NULL and ptr.name != NULL:
                if ptr.type == lib.AV_OPT_TYPE_CONST:
                    ptr += 1
                    continue
                choices = []
                if ptr.unit != NULL:  # option has choices (matching const options)
                    choice_ptr = self.ptr.option
                    while choice_ptr != NULL and choice_ptr.name != NULL:
                        if choice_ptr.type != lib.AV_OPT_TYPE_CONST or choice_ptr.unit != ptr.unit:
                            choice_ptr += 1
                            continue
                        choice_is_default = (choice_ptr.default_val.i64 == ptr.default_val.i64 or
                                             ptr.type == lib.AV_OPT_TYPE_FLAGS and
                                             choice_ptr.default_val.i64 & ptr.default_val.i64)
                        option_choice = wrap_option_choice(choice_ptr, choice_is_default)
                        choices.append(option_choice)
                        choice_ptr += 1
                option = wrap_option(tuple(choices), ptr)
                options.append(option)
                ptr += 1
            self._options = tuple(options)
        return self._options

    def __repr__(self):
        return f"<{self.__class__.__name__} {self.name} at 0x{id(self):x}>"
