import std/[unittest, tables, strutils]
import model, abi, parser, layout

proc analyzeMulti(src: string, targetNames: seq[string]): Table[string, Report] =
  var pr = ParseResult()
  parseFile("test.pxd", src, pr)
  var resolvers: seq[Resolver] = @[]
  for name in targetNames:
    resolvers.add newResolver(pr, getTarget(name))
  for a in pr.aggs:
    if a.hasBody:
      result[a.name] = analyzeAll(resolvers, a)

proc analyze(src: string, targetName = "lp64"): Table[string, Finding] =
  var pr = ParseResult()
  parseFile("test.pxd", src, pr)
  let r = newResolver(pr, getTarget(targetName))
  for a in pr.aggs:
    if a.hasBody:
      result[a.name] = r.analyze(a)

suite "struct layout":
  test "padding between and after members":
    let f = analyze("""
cdef struct S:
    char a
    int b
    char c
""")["S"]
    check f.layout.size == 12
    check f.optimalSize == 8
    check f.wasted == 4
    check f.layout.holes.len == 2
    check f.layout.holes[0].offset == 1
    check f.layout.holes[0].size == 3
    check f.layout.holes[0].after == "a"
    check f.layout.holes[1].tail
    check f.order[0].name == "b"

  test "already optimal structs report nothing":
    let f = analyze("""
cdef struct S:
    int b
    char a
    char c
""")["S"]
    check f.layout.size == 8
    check f.wasted == 0

  test "packed structs are never reordered":
    let f = analyze("""
cdef packed struct S:
    char a
    int b
""")["S"]
    check f.layout.size == 5
    check f.wasted == 0

  test "unions take the widest member":
    let f = analyze("""
cdef union U:
    char a
    double b
    int c
""")["U"]
    check f.layout.size == 8
    check f.layout.align == 8
    check f.wasted == 0

  test "arrays and nested structs":
    let f = analyze("""
cdef struct Inner:
    double d
    char c

cdef struct S:
    char flags[3]
    Inner inner
    int counts[4]
""")
    check f["Inner"].layout.size == 16
    check f["S"].layout.size == 40      # 3 +5 pad, 16, 16
    check f["S"].optimalSize == 40
    check f["S"].layout.fields[2].size == 16

  test "unknown extents are not guessed":
    let f = analyze("""
cdef struct S:
    int n
    char buf[MAX]
""")["S"]
    check not f.layout.complete
    check f.layout.unresolved[0].startsWith("buf")

suite "cdef class layout":
  test "PyObject_HEAD only, no vtable without cdef methods":
    let f = analyze("""
cdef class C:
    cdef int a
    cdef void *p
    cdef int b
""")["C"]
    check f.layout.baseSize == 16
    check not f.layout.vtab
    check f.layout.size == 40       # a, 4 pad, p, b, 4 tail
    check f.optimalSize == 32       # p, a, b
    check f.wasted == 8

  test "a cdef method adds the hidden vtable pointer":
    let f = analyze("""
cdef class C:
    cdef int a
    cdef void run(self)
""")["C"]
    check f.layout.vtab
    check f.layout.baseSize == 24
    check f.layout.size == 32

  test "subclasses inherit the vtable slot, not a second one":
    let f = analyze("""
cdef class Base:
    cdef void *p
    cdef void run(self)

cdef class Sub(Base):
    cdef int x
    cdef void go(self)
""")
    check f["Base"].layout.size == 32       # head + vtab + p
    check f["Sub"].layout.baseSize == 32
    check not f["Sub"].layout.vtab
    check f["Sub"].layout.size == 40

  test "multi-line method declarations are not fields":
    let f = analyze("""
cdef class C:
    cdef int a
    cdef void go(
        self, int x, int y
    )
    cdef int b
""")["C"]
    check f.layout.fields.len == 2
    check f.layout.vtab

  test "docstrings and attribute docstrings are skipped":
    let f = analyze("""
cdef class C:
    '''
    cdef int not_a_field
    '''
    cdef int a
    '''The a value.'''
    cdef int b
""")["C"]
    check f.layout.fields.len == 2
    check f.layout.size == 24

  test "an unknown base class is reported, not assumed":
    let f = analyze("""
cdef class C(SomethingElse):
    cdef int a
""")["C"]
    check not f.layout.complete
    check f.layout.unresolved[0].contains("SomethingElse")

suite "declaration parsing":
  test "one line, several fields":
    let f = analyze("""
cdef class C:
    cdef unsigned int width, height
    cdef char *a, *b
""")["C"]
    check f.layout.fields.len == 4
    check f.layout.fields[0].size == 4
    check f.layout.fields[2].size == 8
    check f.layout.fields[2].decl.ptrDepth == 1

  test "pointer stars bind either way":
    let f = analyze("""
cdef class C:
    cdef lib.AVFrame* a
    cdef lib.AVFrame *b
    cdef const lib.AVCodec *c
""")["C"]
    check f.layout.size == 40
    for lf in f.layout.fields: check lf.size == 8

  test "python containers and generics are one pointer":
    let f = analyze("""
cdef class C:
    cdef dict[str, int] a
    cdef readonly list[Stream] b
    cdef public tuple c
""")["C"]
    check f.layout.size == 40
    check f.layout.fields[0].decl.typeName == "dict"
    check f.layout.fields[1].decl.mods == "readonly "

  test "a qualified C struct is not confused with a class of the same name":
    # av/rational.pxd declares `cdef class AVRational` next to lib.AVRational.
    let f = analyze("""
cdef class AVRational:
    cdef readonly int num
    cdef readonly int den

cdef struct S:
    int a
    lib.AVRational q

cdef class C:
    cdef int a
    cdef lib.AVRational q
    cdef AVRational obj
""")
    check f["S"].layout.size == 12          # not 16: the struct aligns to 4
    check f["S"].layout.align == 4
    check f["S"].layout.fields[1].offset == 4
    check f["C"].layout.fields[1].align == 4
    check f["C"].layout.fields[1].offset == 20
    check f["C"].layout.fields[2].align == 8   # the class, one pointer
    check f["C"].layout.fields[2].size == 8

  test "an untyped class attribute is an object":
    let f = analyze("""
cdef class C:
    cdef readonly planes
    cdef void *p
""")["C"]
    check f.layout.fields.len == 2
    check f.layout.fields[0].decl.name == "planes"
    check f.layout.fields[0].decl.typeName == "object"
    check f.layout.size == 32

  test "a field may be named like a keyword":
    let f = analyze("""
cdef class C:
    cdef lib.AVRational struct
""")["C"]
    check f.layout.fields.len == 1
    check f.layout.fields[0].decl.name == "struct"
    check f.layout.fields[0].size == 8

  test "enums declared in extern blocks size as int":
    let f = analyze("""
cdef extern from "libavutil/pixfmt.h":
    enum AVPixelFormat:
        AV_PIX_FMT_NONE

cdef class C:
    cdef AVPixelFormat fmt
    cdef void *p
""")["C"]
    check f.layout.size == 32
    check f.optimalSize == 32

  test "extern structs are not sized from partial declarations":
    let f = analyze("""
cdef extern from "x.h":
    ctypedef struct AVCodecContext:
        int width

cdef class C:
    cdef AVCodecContext ctx
""")["C"]
    check not f.layout.complete

  test "function pointer typedefs and members are pointers":
    let f = analyze("""
ctypedef void (*Deleter)(void *) noexcept nogil

cdef struct S:
    Deleter d
    void (*cb)(int)
    int n
""")["S"]
    check f.layout.size == 24
    check f.layout.fields[0].size == 8
    check f.layout.fields[1].size == 8

  test "typedef aliases resolve":
    let f = analyze("""
ctypedef int64_t Timestamp

cdef struct S:
    Timestamp t
    int n
""")["S"]
    check f.layout.size == 16

suite "targets":
  test "long is 4 bytes on llp64":
    let src = """
cdef struct S:
    long a
    int b
"""
    check analyze(src, "lp64")["S"].layout.size == 16
    check analyze(src, "llp64")["S"].layout.size == 8

  test "ilp32 shrinks pointers and the object header":
    let f = analyze("""
cdef class C:
    cdef void *p
    cdef int n
""", "ilp32")["C"]
    check f.layout.baseSize == 8
    check f.layout.size == 16

suite "regression: PyAV declarations":
  test "HWAccel matches the compiled extension":
    let f = analyze("""
cdef class HWAccel:
    cdef str _device
    cdef readonly Codec codec
    cdef readonly HWConfig config
    cdef lib.AVBufferRef *ptr
    cdef public dict options
    cdef int _device_type
    cdef readonly int device_id
    cdef public int flags
    cdef readonly bint is_hw_owned
    cdef public bint allow_software_fallback

cdef class Codec:
    cdef const lib.AVCodec *ptr

cdef class HWConfig:
    cdef object __weakref__
    cdef const lib.AVCodecHWConfig *ptr
    cdef void _init(self, const lib.AVCodecHWConfig *ptr)
""")
    check f["HWAccel"].layout.size == 80
    check f["HWAccel"].wasted == 0
    check f["HWConfig"].layout.size == 40    # head + vtab + __weakref__ + ptr
    check f["HWConfig"].layout.vtab

  test "the suggested order really is smaller":
    let f = analyze("""
cdef class C:
    cdef char tag
    cdef void *p
    cdef int n
    cdef double d
    cdef bint on
""")["C"]
    check f.layout.size == 56       # tag, 7 pad, p, n, 4 pad, d, on, 4 tail
    check f.optimalSize == 48       # p, d, n, on, tag, 7 tail
    check f.wasted == 8
    check f.order[0].name == "p"
    check f.order[^1].name == "tag"

suite "across ABIs":
  test "a layout clean on lp64 can have a hole on llp64":
    # `long` is 8 bytes on lp64 and 4 on 64-bit Windows, so this packs on one
    # and leaves a hole on the other. Checking only the host would miss it.
    let r = analyzeMulti("""
cdef struct S:
    long a
    void *p
    long b
""", @["lp64", "llp64"])["S"]
    check r.results[0].layout.size == 24
    check r.results[0].wasted == 0
    check r.results[1].layout.size == 24
    check r.results[1].wasted == 8
    check r.worstWaste == 8
    check r.worstTarget == "llp64"
    check r.changed
    check r.order[0].name == "p"

  test "waste on one ABI is reported even when another is fine":
    let r = analyzeMulti("""
cdef struct S:
    int a
    void *p
    long b
    int c
""", @["lp64", "llp64"])["S"]
    check r.results[0].wasted == 8      # lp64: 32 -> 24
    check r.results[1].wasted == 0      # llp64: already 24
    check r.worstTarget == "lp64"

  test "the suggested order never costs an ABI more than it had":
    let r = analyzeMulti("""
cdef struct S:
    char tag
    long a
    void *p
    double d
    int n
""", @["lp64", "darwin-arm64", "llp64", "ilp32"])["S"]
    for t in r.results:
      check t.suggested <= t.layout.size

  test "a declaration that is already best everywhere suggests nothing":
    let r = analyzeMulti("""
cdef struct S:
    void *p
    int a
    int b
""", @["lp64", "llp64", "ilp32"])["S"]
    check not r.changed
    check r.worstWaste == 0

  test "ABI-defined structs are sized per target, not from a table":
    # Py_buffer is 7 pointers, 2 Py_ssize_t and 2 int.
    let r = analyzeMulti("""
cdef class C:
    cdef Py_buffer view
""", @["lp64", "ilp32"])["C"]
    check r.results[0].layout.size == 96    # 16 head + 80
    check r.results[1].layout.size == 52    # 8 head + 44

  test "unions and packed structs are never reordered":
    let r = analyzeMulti("""
cdef packed struct S:
    char a
    int b
    char c
""", @["lp64", "llp64"])["S"]
    check not r.changed
    check r.results[0].layout.size == 6
