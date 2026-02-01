import cython
import cython.cimports.libav as lib
from cython.cimports.av.option import (
    Option,
    OptionChoice,
    wrap_option,
    wrap_option_choice,
)

_cinit_sentinel = cython.declare(object, object())


@cython.cfunc
def wrap_avclass(ptr: cython.pointer[cython.const[lib.AVClass]]) -> Descriptor | None:
    if ptr == cython.NULL:
        return None
    obj: Descriptor = Descriptor(_cinit_sentinel)
    obj.ptr = ptr
    return obj


@cython.cclass
class Descriptor:
    def __cinit__(self, sentinel):
        if sentinel is not _cinit_sentinel:
            raise RuntimeError("Cannot construct av.Descriptor")

    @property
    def name(self):
        return self.ptr.class_name if self.ptr.class_name else None

    @property
    def options(self):
        ptr: cython.pointer[cython.const[lib.AVOption]] = self.ptr.option
        choice_ptr: cython.pointer[cython.const[lib.AVOption]]
        option: Option
        option_choice: OptionChoice
        choice_is_default: cython.bint
        if self._options is None:
            options: list = []
            ptr = self.ptr.option
            while ptr != cython.NULL and ptr.name != cython.NULL:
                if ptr.type == lib.AV_OPT_TYPE_CONST:
                    ptr += 1
                    continue
                choices: list = []
                if (
                    ptr.unit != cython.NULL
                ):  # option has choices (matching const options)
                    choice_ptr = self.ptr.option
                    while choice_ptr != cython.NULL and choice_ptr.name != cython.NULL:
                        if (
                            choice_ptr.type != lib.AV_OPT_TYPE_CONST
                            or choice_ptr.unit != ptr.unit
                        ):
                            choice_ptr += 1
                            continue
                        choice_is_default = (
                            choice_ptr.default_val.i64 == ptr.default_val.i64
                            or ptr.type == lib.AV_OPT_TYPE_FLAGS
                            and choice_ptr.default_val.i64 & ptr.default_val.i64
                        )
                        option_choice = wrap_option_choice(
                            choice_ptr, choice_is_default
                        )
                        choices.append(option_choice)
                        choice_ptr += 1
                option = wrap_option(tuple(choices), ptr)
                options.append(option)
                ptr += 1
            self._options = tuple(options)
        return self._options

    def __repr__(self):
        return f"<{self.__class__.__name__} {self.name} at 0x{id(self):x}>"
