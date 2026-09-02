## Data types shared by the parser, the layout engine and the CLI.

type
  AggKind* = enum
    akClass = "cdef class"
    akStruct = "struct"
    akUnion = "union"

  Target* = object
    name*: string
    ptrSize*, ptrAlign*: int
    longSize*, longAlign*: int
    ldSize*, ldAlign*: int      ## long double
    maxScalarAlign*: int        ## i386 aligns double and long long to 4
    headSize*: int              ## sizeof(PyObject_HEAD)

  FieldDecl* = object
    name*: string
    typeName*: string     ## base type as written, qualifiers and subscript removed
    mods*: string         ## "readonly ", "public " or ""
    display*: string      ## paste-ready declaration line
    ptrDepth*: int
    arrayLen*: int        ## 1 when scalar, -1 when the extent is not a literal
    line*: int

  Aggregate* = object
    kind*: AggKind
    name*: string
    base*: string         ## base class for akClass, "" when object
    packed*: bool
    isExtern*: bool
    hasBody*: bool        ## false for forward declarations
    hasCMethods*: bool    ## declares a cdef/cpdef method, so it needs a vtable
    file*: string
    line*: int
    fields*: seq[FieldDecl]

  Hole* = object
    offset*, size*: int
    after*: string        ## field the hole follows ("" = the object header)
    tail*: bool

  LaidField* = object
    decl*: FieldDecl
    offset*, size*, align*: int

  Layout* = object
    size*, align*, baseSize*: int
    vtab*: bool           ## a hidden __pyx_vtab pointer is part of baseSize
    complete*: bool       ## every field resolved to a concrete size
    fields*: seq[LaidField]
    holes*: seq[Hole]
    unresolved*: seq[string]

  Finding* = object
    agg*: Aggregate
    layout*: Layout
    optimalSize*: int
    order*: seq[FieldDecl]  ## fields in the suggested order

  TargetResult* = object
    target*: string
    layout*: Layout
    optimalSize*: int       ## best this ABI could do on its own
    suggested*: int         ## what the shared suggested order costs here
    unresolved*: seq[string]

  Report* = object
    ## One aggregate measured against several ABIs at once. The declaration has
    ## a single field order, so the suggestion has to suit all of them.
    agg*: Aggregate
    results*: seq[TargetResult]
    order*: seq[FieldDecl]
    changed*: bool          ## the suggestion differs from the declared order
    sized*: int             ## how many targets could be measured

func wasted*(f: Finding): int =
  f.layout.size - f.optimalSize

func complete*(t: TargetResult): bool = t.layout.complete

func wasted*(t: TargetResult): int =
  ## What the suggested order would actually save on this ABI.
  if t.layout.complete: t.layout.size - t.suggested else: 0

func worstWaste*(r: Report): int =
  for t in r.results: result = max(result, t.wasted)

func worstTarget*(r: Report): string =
  var worst = -1
  for t in r.results:
    if t.wasted > worst:
      worst = t.wasted
      result = t.target

func isArray*(f: FieldDecl): bool =
  f.arrayLen != 1
