## Resolves field types to sizes and lays aggregates out per the target ABI.

import std/[strutils, tables, sets, sequtils, algorithm]
import model, abi, parser

type
  Resolver* = ref object
    target*: Target
    aggs*: Table[string, Aggregate]        ## structs and unions
    classAggs*: Table[string, Aggregate]   ## cdef classes, a separate namespace
    classes*: HashSet[string]
    enums*: HashSet[string]
    aliases*: Table[string, string]
    assumed*: Table[string, tuple[size, align: int]]
    memo: Table[string, Layout]
    inProgress: HashSet[string]

func simpleName*(s: string): string =
  let dot = s.rfind('.')
  if dot >= 0: s[dot + 1 .. ^1] else: s

proc newResolver*(pr: ParseResult, t: Target): Resolver =
  result = Resolver(target: t, classes: pr.classes, enums: pr.enums,
                    aliases: pr.aliases)
  for a in pr.aggs:
    if not a.hasBody: continue
    # A cdef class and a C struct may share a name (`AVRational` does), so they
    # are kept apart: a qualified type name means the struct, a bare one the class.
    if a.kind == akClass:
      if a.name notin result.classAggs: result.classAggs[a.name] = a
      continue
    # First definition wins, but a non-extern one always beats an extern one.
    if a.name in result.aggs and not (result.aggs[a.name].isExtern and not a.isExtern):
      continue
    result.aggs[a.name] = a

  # Fill in the ABI-defined structs, but never over a real definition: an
  # extern declaration lists only the members Cython was told about, so the
  # built-in wins over that, and a full definition in the sources wins over
  # the built-in.
  var builtins = ParseResult()
  parseFile("<builtin>", builtinDecls, builtins)
  for a in builtins.aggs:
    if a.name notin result.aggs or result.aggs[a.name].isExtern:
      result.aggs[a.name] = a

proc layoutAgg*(r: Resolver, a: Aggregate): Layout

func key(a: Aggregate): string = $a.kind & " " & a.name

proc sizeOf(r: Resolver, a: Aggregate): tuple[size, align: int, ok: bool] =
  if key(a) in r.inProgress: return (0, 0, false)   # recursive by value
  let lay = r.layoutAgg(a)
  if lay.complete: (lay.size, lay.align, true) else: (0, 0, false)

proc sizeOfStruct(r: Resolver, name: string): tuple[size, align: int, ok: bool] =
  if not r.aggs.hasKey(name): return (0, 0, false)
  let a = r.aggs[name]
  # A struct declared inside `cdef extern` lists only the members Cython was
  # told about, so its field list cannot be trusted for a size.
  if a.isExtern: return (0, 0, false)
  r.sizeOf(a)

proc sizeOfClass(r: Resolver, name: string): tuple[size, align: int, ok: bool] =
  if not r.classAggs.hasKey(name): return (0, 0, false)
  r.sizeOf(r.classAggs[name])

proc sizeOfType*(r: Resolver, typeName: string, ptrDepth, arrayLen: int):
    tuple[size, align: int, ok: bool] =
  var base: tuple[size, align: int, ok: bool]
  if ptrDepth > 0:
    base = (r.target.ptrSize, r.target.ptrAlign, true)
  else:
    var name = simpleName(typeName)
    var hops = 0
    while r.aliases.hasKey(name) and hops < 8:
      name = simpleName(r.aliases[name])
      if name.endsWith("*"): return (r.target.ptrSize, r.target.ptrAlign, true)
      inc hops
    # `lib.AVRational` is FFmpeg's two-int struct; a bare `AVRational` is the
    # cdef class of the same name. Qualified names take the C meaning first.
    let qualified = typeName.contains('.')
    template asPyObject(): untyped =
      (name in pyObjectTypes or name in r.classes)
    if r.assumed.hasKey(name):
      let a = r.assumed[name]
      base = (a.size, a.align, true)
    else:
      base = cScalar(name, r.target)
      if not base.ok and not qualified and asPyObject():
        base = (r.target.ptrSize, r.target.ptrAlign, true)
      if not base.ok and name in r.enums:
        base = (4, 4, true)
      if not base.ok:
        base = r.sizeOfStruct(name)
      if not base.ok and qualified and asPyObject():
        base = (r.target.ptrSize, r.target.ptrAlign, true)
  if not base.ok: return base
  if arrayLen < 0: return (0, 0, false)
  (base.size * arrayLen, base.align, true)

proc baseOfClass(r: Resolver, a: Aggregate): tuple[size, align: int, ok: bool] =
  if a.base.len == 0:
    return (r.target.headSize, r.target.ptrAlign, true)
  r.sizeOfClass(a.base)

proc ancestorHasVtab(r: Resolver, a: Aggregate): bool =
  ## Cython puts the `__pyx_vtab` pointer in the topmost class that declares a
  ## cdef method; every subclass inherits that slot rather than adding its own.
  var name = a.base
  var hops = 0
  while name.len > 0 and hops < 16:
    if not r.classAggs.hasKey(name): return false
    let b = r.classAggs[name]
    if b.hasCMethods: return true
    name = b.base
    inc hops
  false

proc classBase(r: Resolver, a: Aggregate): tuple[size, align: int, ok, vtab: bool] =
  if a.kind != akClass: return (0, 1, true, false)
  let b = r.baseOfClass(a)
  var size = b.size
  var align = b.align
  var vtab = false
  if a.hasCMethods and not r.ancestorHasVtab(a):
    size += r.target.ptrSize
    align = max(align, r.target.ptrAlign)
    vtab = true
  (size, align, b.ok, vtab)

proc layoutFields(r: Resolver, a: Aggregate, fields: seq[FieldDecl],
                  baseSize, baseAlign: int, collectHoles: bool): Layout =
  result.baseSize = baseSize
  result.align = max(1, baseAlign)
  result.complete = true
  var offset = baseSize

  for f in fields:
    let sz = r.sizeOfType(f.typeName, f.ptrDepth, f.arrayLen)
    if not sz.ok:
      result.complete = false
      result.unresolved.add f.name & ": " & f.typeName &
        (if f.arrayLen < 0: "[]" else: "")
      continue
    let align = if a.packed: 1 else: sz.align
    result.align = max(result.align, align)
    if a.kind == akUnion:
      result.fields.add LaidField(decl: f, offset: baseSize, size: sz.size,
                                  align: align)
      offset = max(offset, baseSize + sz.size)
      continue
    let pad = (align - (offset mod align)) mod align
    if pad > 0 and collectHoles:
      result.holes.add Hole(offset: offset, size: pad,
        after: (if result.fields.len > 0: result.fields[^1].decl.name else: ""))
    offset += pad
    result.fields.add LaidField(decl: f, offset: offset, size: sz.size,
                                align: align)
    offset += sz.size

  let tail = (result.align - (offset mod result.align)) mod result.align
  if tail > 0 and collectHoles:
    result.holes.add Hole(offset: offset, size: tail, tail: true,
      after: (if result.fields.len > 0: result.fields[^1].decl.name else: ""))
  result.size = offset + tail

proc layoutAgg*(r: Resolver, a: Aggregate): Layout =
  if r.memo.hasKey(key(a)): return r.memo[key(a)]
  r.inProgress.incl key(a)
  defer: r.inProgress.excl key(a)

  let b = r.classBase(a)
  result = r.layoutFields(a, a.fields, b.size, b.align, true)
  result.vtab = b.vtab
  if not b.ok:
    result.complete = false
    result.unresolved.insert("base class: " & a.base, 0)
  if result.complete:
    r.memo[key(a)] = result

func orderKey(f: LaidField): (int, int) = (-f.align, -f.size)

proc sizeUnder*(r: Resolver, a: Aggregate, order: seq[FieldDecl]):
    tuple[size: int, ok: bool] =
  ## What this aggregate would measure with its fields in the given order.
  let b = r.classBase(a)
  let lay = r.layoutFields(a, order, b.size, b.align, false)
  (lay.size, lay.complete and b.ok)

proc optimize*(r: Resolver, a: Aggregate, lay: Layout): tuple[size: int, order: seq[FieldDecl]] =
  ## Descending alignment, then descending size, ties broken by original order.
  if a.kind == akUnion or a.packed or not lay.complete:
    return (lay.size, lay.fields.mapIt(it.decl))
  var sorted = lay.fields
  sorted.sort(proc (x, y: LaidField): int = cmp(orderKey(x), orderKey(y)))
  (r.sizeUnder(a, sorted.mapIt(it.decl)).size, sorted.mapIt(it.decl))

proc analyze*(r: Resolver, a: Aggregate): Finding =
  let lay = r.layoutAgg(a)
  let opt = r.optimize(a, lay)
  Finding(agg: a, layout: lay, optimalSize: opt.size, order: opt.order)

func names(order: seq[FieldDecl]): seq[string] = order.mapIt(it.name)

proc analyzeAll*(resolvers: seq[Resolver], a: Aggregate): Report =
  ## Measures `a` against every ABI and picks one field order for all of them.
  ## A `.pxd` has a single declaration, so an order that is perfect on LP64 but
  ## poor on LLP64 is not a fix; the candidates are each ABI's own best order
  ## plus the declared one, scored by their total size everywhere.
  result.agg = a
  var candidates = @[a.fields]
  for r in resolvers:
    let f = r.analyze(a)
    result.results.add TargetResult(target: r.target.name, layout: f.layout,
      optimalSize: f.optimalSize, suggested: f.layout.size,
      unresolved: f.layout.unresolved)
    if not f.layout.complete: continue
    inc result.sized
    if a.kind == akUnion or a.packed: continue
    if not candidates.anyIt(names(it) == names(f.order)): candidates.add f.order

  if result.sized == 0:
    result.order = a.fields
    return

  var best = 0
  var bestScore = (high(int), high(int))
  for ci, cand in candidates:
    var total = 0
    var first = high(int)
    var ok = true
    for ti, r in resolvers:
      if not result.results[ti].layout.complete: continue
      let s = r.sizeUnder(a, cand)
      if not s.ok:
        ok = false
        break
      total += s.size
      if first == high(int): first = s.size
    # Ties keep the earliest candidate, and the declared order comes first, so
    # a reshuffle is only ever suggested when it actually buys something.
    if ok and (total, first) < bestScore:
      bestScore = (total, first)
      best = ci

  result.order = candidates[best]
  result.changed = names(result.order) != names(a.fields)
  for ti, r in resolvers:
    if result.results[ti].layout.complete:
      result.results[ti].suggested = r.sizeUnder(a, result.order).size
