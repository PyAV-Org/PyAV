## A tolerant, line-oriented reader for Cython .pxd declarations.
##
## It is deliberately not a real Cython parser: it recognizes aggregate headers
## and member declarations, and skips anything it does not understand rather
## than failing.

import std/[strutils, sequtils, tables, sets]
import model

type
  ParseResult* = object
    aggs*: seq[Aggregate]
    classes*: HashSet[string]   ## every name declared as `cdef class`
    enums*: HashSet[string]     ## enum tags (int-sized)
    aliases*: Table[string, string]

  LogicalLine = object
    indent: int
    text: string
    line: int

  CtxKind = enum
    ckExtern, ckAgg, ckOther

  Ctx = object
    kind: CtxKind
    indent: int
    agg: int

const
  cKeywords = ["unsigned", "signed", "long", "short", "int", "char", "float",
               "double", "void", "_Bool", "complex"]
  qualifiers = ["const", "volatile", "static", "struct", "union", "enum"]
  quotePrefixes = {'r', 'b', 'u', 'f', 'R', 'B', 'U', 'F'}

func leadingIndent(s: string): int =
  for c in s:
    if c == ' ': inc result
    elif c == '\t': result += 8 - (result mod 8)
    else: break

func stripComment(s: string): string =
  var quote = '\0'
  var i = 0
  while i < s.len:
    let c = s[i]
    if quote != '\0':
      if c == '\\': inc i
      elif c == quote: quote = '\0'
    elif c in {'\'', '"'}: quote = c
    elif c == '#': return s[0 ..< i]
    inc i
  s

func bracketDelta(s: string): int =
  var quote = '\0'
  var i = 0
  while i < s.len:
    let c = s[i]
    if quote != '\0':
      if c == '\\': inc i
      elif c == quote: quote = '\0'
    elif c in {'\'', '"'}: quote = c
    elif c in {'(', '[', '{'}: inc result
    elif c in {')', ']', '}'}: dec result
    inc i

func logicalLines(src: string): seq[LogicalLine] =
  ## Drops blank lines, comments and docstrings; joins bracket and backslash
  ## continuations into one entry.
  let raw = src.splitLines()
  var i = 0
  var docDelim = ""
  while i < raw.len:
    let stripped = raw[i].strip()
    if docDelim.len > 0:
      if stripped.contains(docDelim): docDelim = ""
      inc i
      continue
    var body = stripped
    while body.len > 0 and body[0] in quotePrefixes: body = body[1 .. ^1]
    if body.startsWith("\"\"\"") or body.startsWith("'''"):
      let d = body[0 .. 2]
      if not body[3 .. ^1].contains(d): docDelim = d
      inc i
      continue
    var text = stripComment(raw[i])
    if text.strip().len == 0:
      inc i
      continue
    let indent = leadingIndent(text)
    let startLine = i + 1
    var acc = text.strip()
    var depth = bracketDelta(acc)
    while (depth > 0 or acc.endsWith("\\")) and i + 1 < raw.len:
      if acc.endsWith("\\"): acc.setLen(acc.len - 1)
      inc i
      let nxt = stripComment(raw[i]).strip()
      depth += bracketDelta(nxt)
      acc = acc.strip() & " " & nxt
    result.add LogicalLine(indent: indent, text: acc.strip(), line: startLine)
    inc i

func words(s: string): seq[string] =
  s.split({' ', '\t'}).filterIt(it.len > 0)

func tokenize(s: string): seq[string] =
  ## Splits a declaration into identifiers (with any `[...]` subscript attached),
  ## `*` and `,`.
  var i = 0
  while i < s.len:
    let c = s[i]
    if c in {' ', '\t'}:
      inc i
    elif c == '*':
      result.add "*"
      inc i
    elif c == ',':
      result.add ","
      inc i
    elif c == '[':
      let start = i
      var depth = 0
      while i < s.len:
        if s[i] == '[': inc depth
        elif s[i] == ']':
          dec depth
          if depth == 0:
            inc i
            break
        inc i
      let group = s[start ..< i]
      if result.len > 0 and result[^1] notin ["*", ","]:
        result[^1] = result[^1] & group
      else:
        result.add group
    else:
      let start = i
      while i < s.len and (s[i].isAlphaNumeric or s[i] in {'_', '.'}): inc i
      if i == start: inc i
      else: result.add s[start ..< i]

func parseExtent(sub: string): int =
  ## `[8]` -> 8, `[4][2]` -> 8, anything non-literal -> -1.
  result = 1
  var i = 0
  while i < sub.len:
    if sub[i] == '[':
      let close = sub.find(']', i)
      if close < 0: return -1
      let inner = sub[i + 1 ..< close].strip()
      var n: int
      try:
        n = parseInt(inner)
      except ValueError:
        return -1
      result *= n
      i = close + 1
    else:
      inc i

proc parseMember(decl, srcLine: string, isClass: bool, lineNo: int): seq[FieldDecl] =
  ## `decl` is the declaration with any leading `cdef` already removed.
  var rest = decl.strip()
  var mods = ""
  while true:
    let w = rest.words()
    if w.len == 0: return
    if isClass and w[0] in ["readonly", "public"]:
      mods = w[0] & " "
      rest = rest[w[0].len .. ^1].strip()
    elif w[0] in ["const", "volatile", "static"]:
      rest = rest[w[0].len .. ^1].strip()
    else:
      break

  let toks = tokenize(rest)
  if toks.len == 0: return

  var parts: seq[string]
  var idx = 0
  while idx < toks.len:
    let t = toks[idx]
    if t in qualifiers:
      inc idx
    elif t in cKeywords:
      parts.add t
      inc idx
    elif parts.len == 0:
      parts.add t
      inc idx
      break
    else:
      break
  if parts.len == 0: return
  if idx >= toks.len:
    # `cdef readonly planes` — an untyped class attribute is an object.
    if isClass and parts.len == 1 and parts[0] notin cKeywords and
       not parts[0].contains('.') and not parts[0].contains('['):
      return @[FieldDecl(name: parts[0], typeName: "object", mods: mods,
                         display: srcLine.strip(), arrayLen: 1, line: lineNo)]
    return

  var typeName = parts.join(" ")
  let sub = typeName.find('[')
  if sub >= 0: typeName = typeName[0 ..< sub]

  var groups: seq[seq[string]] = @[@[]]
  for t in toks[idx .. ^1]:
    if t == ",": groups.add @[]
    else: groups[^1].add t

  var res: seq[FieldDecl] = @[]
  for g in groups:
    var f = FieldDecl(typeName: typeName, mods: mods, arrayLen: 1, line: lineNo)
    for t in g:
      if t == "*": inc f.ptrDepth
      elif f.name.len == 0:
        let br = t.find('[')
        if br >= 0:
          f.name = t[0 ..< br]
          f.arrayLen = parseExtent(t[br .. ^1])
        else:
          f.name = t
    if f.name.len == 0: return @[]
    res.add f

  for i in 0 ..< res.len:
    if res.len == 1:
      res[i].display = srcLine.strip()
    else:
      let stars = repeat('*', res[i].ptrDepth)
      let arr = if res[i].arrayLen == 1: "" else: "[" & $res[i].arrayLen & "]"
      res[i].display = (if isClass: "cdef " else: "") & res[i].mods &
        parts.join(" ") & " " & stars & res[i].name & arr
  res

func headerName(tokens: seq[string], at: int): string =
  ## Name of an aggregate header, cut at `(` or `:`.
  if at >= tokens.len: return ""
  result = tokens[at]
  for stop in ['(', ':']:
    let i = result.find(stop)
    if i >= 0: result = result[0 ..< i]

func baseName(text: string): string =
  ## `cdef class VideoFrame(Frame):` -> `Frame`
  let o = text.find('(')
  if o < 0: return ""
  let c = text.find(')', o)
  if c < 0: return ""
  result = text[o + 1 ..< c].strip()
  let dot = result.rfind('.')
  if dot >= 0: result = result[dot + 1 .. ^1]

proc parseFile*(path, src: string, pr: var ParseResult) =
  var stack: seq[Ctx] = @[]
  for ll in logicalLines(src):
    while stack.len > 0 and ll.indent <= stack[^1].indent:
      discard stack.pop()

    let text = ll.text
    let w = text.words()
    if w.len == 0: continue
    let opensBlock = text.endsWith(":")
    let inExtern = stack.anyIt(it.kind == ckExtern)

    # `cdef extern from "libavutil/x.h" nogil:`
    if w.len >= 3 and w[0] == "cdef" and w[1] == "extern":
      stack.add Ctx(kind: ckExtern, indent: ll.indent, agg: -1)
      continue

    var head = w
    var packed = false
    if head[0] == "ctypedef" or head[0] == "cdef" or head[0] == "cpdef":
      head = head[1 .. ^1]
    if head.len > 0 and head[0] == "api":
      head = head[1 .. ^1]
    if head.len > 0 and head[0] == "packed":
      packed = true
      head = head[1 .. ^1]
    if head.len == 0: continue

    case head[0]
    of "class":
      let name = headerName(head, 1)
      if name.len == 0: continue
      pr.classes.incl name
      pr.aggs.add Aggregate(kind: akClass, name: name, base: baseName(text),
                            isExtern: inExtern, hasBody: opensBlock, file: path,
                            line: ll.line)
      if opensBlock:
        stack.add Ctx(kind: ckAgg, indent: ll.indent, agg: pr.aggs.high)
      continue
    of "struct", "union":
      let name = headerName(head, 1)
      if name.len == 0: continue
      let kind = if head[0] == "struct": akStruct else: akUnion
      pr.aggs.add Aggregate(kind: kind, name: name, packed: packed,
                            isExtern: inExtern, hasBody: opensBlock, file: path,
                            line: ll.line)
      if opensBlock:
        stack.add Ctx(kind: ckAgg, indent: ll.indent, agg: pr.aggs.high)
      continue
    of "enum":
      let name = headerName(head, 1)
      if name.len > 0: pr.enums.incl name
      if opensBlock:
        stack.add Ctx(kind: ckOther, indent: ll.indent, agg: -1)
      continue
    else:
      discard

    # `ctypedef void (*Deleter)(Foo*) nogil`
    if w[0] == "ctypedef" and text.contains("(*"):
      let open = text.find("(*")
      var i = open + 2
      var name = ""
      while i < text.len and (text[i].isAlphaNumeric or text[i] == '_'):
        name.add text[i]
        inc i
      if name.len > 0: pr.aliases[name] = "void *"
      continue

    # `ctypedef int64_t Timestamp`
    if w[0] == "ctypedef" and not opensBlock and w.len >= 3 and not text.contains("("):
      let toks = tokenize(text[w[0].len .. ^1])
      if toks.len >= 2 and toks[^1] notin ["*", ","]:
        let alias = toks[^1]
        var aliased = toks[0 ..< toks.high].filterIt(it != "*").join(" ")
        if toks.anyIt(it == "*"): aliased = "void *"
        pr.aliases[alias] = aliased
      continue

    if opensBlock:
      stack.add Ctx(kind: ckOther, indent: ll.indent, agg: -1)
      continue

    if stack.len == 0 or stack[^1].kind != ckAgg: continue
    let ai = stack[^1].agg
    let isClass = pr.aggs[ai].kind == akClass

    var decl = text
    if isClass:
      if w[0] notin ["cdef", "cpdef"]: continue
      decl = text[w[0].len .. ^1]
    if decl.strip() == "pass": continue
    # Bitfields change the layout rules; refuse to guess rather than be wrong.
    if decl.contains(':'):
      pr.aggs[ai].fields.add FieldDecl(name: decl.strip(), typeName: "<bitfield>",
        display: text.strip(), arrayLen: 1, line: ll.line)
      continue
    # Methods and function declarations; `(*name)(...)` is a function pointer field.
    if decl.contains('(') and not decl.contains("(*"):
      # A cdef/cpdef method puts the class in a vtable; `def` methods do not.
      if isClass and w[0] in ["cdef", "cpdef"]:
        pr.aggs[ai].hasCMethods = true
      continue
    if decl.contains("(*"):
      let open = decl.find("(*")
      var i = open + 2
      var name = ""
      while i < decl.len and (decl[i].isAlphaNumeric or decl[i] == '_'):
        name.add decl[i]
        inc i
      if name.len > 0:
        pr.aggs[ai].fields.add FieldDecl(name: name, typeName: "void",
          mods: "", display: text.strip(), ptrDepth: 1, arrayLen: 1, line: ll.line)
      continue

    for f in parseMember(decl, text, isClass, ll.line):
      pr.aggs[ai].fields.add f
