## Target ABIs and the built-in type table.

import std/[strutils, sets]
import model

const
  targetNames* = ["lp64", "darwin-arm64", "llp64", "armv7", "ilp32"]

proc getTarget*(name: string): Target =
  ## `lp64` is the x86-64 System V ABI, `llp64` is 64-bit Windows.
  case name.toLowerAscii
  of "lp64", "linux", "sysv":  # x86-64 System V
    Target(name: "lp64", ptrSize: 8, ptrAlign: 8, longSize: 8, longAlign: 8,
           ldSize: 16, ldAlign: 16, maxScalarAlign: 8, headSize: 16)
  of "darwin-arm64", "macos", "arm64":
    Target(name: "darwin-arm64", ptrSize: 8, ptrAlign: 8, longSize: 8, longAlign: 8,
           ldSize: 8, ldAlign: 8, maxScalarAlign: 8, headSize: 16)
  of "llp64", "windows", "win64":
    Target(name: "llp64", ptrSize: 8, ptrAlign: 8, longSize: 4, longAlign: 4,
           ldSize: 8, ldAlign: 8, maxScalarAlign: 8, headSize: 16)
  of "armv7", "armhf", "armv7l":  # 32-bit ARM, arm-linux-gnueabihf
    # ILP32 like i386, but AAPCS aligns double and long long to 8, and
    # long double is just double.
    Target(name: "armv7", ptrSize: 4, ptrAlign: 4, longSize: 4, longAlign: 4,
           ldSize: 8, ldAlign: 8, maxScalarAlign: 8, headSize: 8)
  of "ilp32", "x86":           # 32-bit x86 System V
    Target(name: "ilp32", ptrSize: 4, ptrAlign: 4, longSize: 4, longAlign: 4,
           ldSize: 12, ldAlign: 4, maxScalarAlign: 4, headSize: 8)
  else:
    raise newException(ValueError, "unknown target '" & name & "', expected one of " &
      targetNames.join(", "))

const pyObjectTypes* = toHashSet([
  "object", "str", "bytes", "unicode", "bytearray", "dict", "list", "tuple",
  "set", "frozenset", "type", "slice", "complex", "BaseException", "Exception",
  "basestring", "memoryview", "array"])

## Multi-word C base types, keyed by their normalized spelling.
proc cScalar*(name: string, t: Target): tuple[size, align: int, ok: bool] =
  template r(s: int): untyped = (s, min(s, t.maxScalarAlign), true)
  case name
  of "char", "signed char", "unsigned char", "_Bool", "bool": r(1)
  of "short", "short int", "unsigned short", "unsigned short int",
     "signed short", "signed short int": r(2)
  of "int", "signed", "signed int", "unsigned", "unsigned int": r(4)
  of "long", "long int", "unsigned long", "unsigned long int",
     "signed long", "signed long int": (t.longSize, t.longAlign, true)
  of "long long", "long long int", "unsigned long long",
     "unsigned long long int", "signed long long", "signed long long int": r(8)
  of "float": r(4)
  of "double": r(8)
  of "long double": (t.ldSize, t.ldAlign, true)
  of "float complex": r(8)
  of "double complex": r(16)
  # Fixed-width and semantic integers.
  of "int8_t", "uint8_t": r(1)
  of "int16_t", "uint16_t", "char16_t": r(2)
  of "int32_t", "uint32_t", "char32_t": r(4)
  of "int64_t", "uint64_t": r(8)
  of "size_t", "ssize_t", "Py_ssize_t", "ptrdiff_t", "intptr_t", "uintptr_t",
     "Py_hash_t", "Py_uintptr_t", "uintmax_t", "intmax_t":
    (t.ptrSize, t.ptrAlign, true)
  of "Py_UCS4", "wchar_t": r(4)
  of "Py_UCS2": r(2)
  of "Py_UCS1": r(1)
  of "bint": r(4)              # Cython lowers bint to int
  of "void": (0, 1, false)     # only legal behind a pointer
  else: (0, 0, false)

## Structs whose layout is fixed by an ABI we can rely on, written as ordinary
## declarations so that every target computes them itself instead of trusting a
## number measured on one machine. A real definition in the sources being linted
## takes precedence over these.
const builtinDecls* = """
cdef struct AVRational:
    int num
    int den

cdef union AVChannelLayoutU:
    uint64_t mask
    void *map

cdef struct AVChannelLayout:
    int order
    int nb_channels
    AVChannelLayoutU u
    void *opaque

cdef struct AVIndexEntry:
    int64_t pos
    int64_t timestamp
    int flags_and_size
    int min_distance

cdef struct AVSubtitle:
    uint16_t format
    uint32_t start_display_time
    uint32_t end_display_time
    unsigned int num_rects
    void *rects
    int64_t pts

cdef struct PyObject:
    Py_ssize_t ob_refcnt
    void *ob_type

cdef struct Py_buffer:
    void *buf
    void *obj
    Py_ssize_t len
    Py_ssize_t itemsize
    int readonly
    int ndim
    char *format
    Py_ssize_t *shape
    Py_ssize_t *strides
    Py_ssize_t *suboffsets
    void *internal
"""
