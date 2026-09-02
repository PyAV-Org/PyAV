import std/[strutils, sequtils, os, parseopt, sets, tables, terminal]
import model, abi, parser, layout

const
  version = "pxdpad 0.1.0"
  skipDirs = ["venvs", "venv", ".venv", "build", "dist", ".git", "vendor",
              ".eggs", "node_modules", "__pycache__"]
  usage = """
$1

Usage: pxdpad [options] [path ...]

Reports padding holes in `cdef class` and `cdef struct` declarations, and the
field order that removes them. Paths may be .pxd files or directories (searched
recursively); the default is the working directory.

Every ABI is checked by default ($2), because a
declaration that packs tightly on one platform can have holes on another: `long`
is 4 bytes on 64-bit Windows, and pointers are 4 bytes on 32-bit. A .pxd has one
field order for all of them, so the suggested order is the one that measures
smallest across every ABI checked, not the best for any single one.

Options:
  -t, --target:NAMES     restrict to these ABIs, comma-separated. One of
                         $2
  -m, --min-waste:N      only report types wasting at least N bytes (default: 1)
  -a, --all              list every type, including those with no waste
      --assume:T=SZ[:AL] give type T a size (and alignment); repeatable
      --include-extern   also analyze declarations inside `cdef extern` blocks
      --no-suggest       omit the suggested field order
  -v, --verbose          list types that could not be sized
      --exit-zero        always exit 0, even when findings are reported
  -h, --help             show this help
  -V, --version          show the version

Exit status is 1 when a type wastes --min-waste bytes or more on any ABI
checked, unless --exit-zero is given.
"""

type Options = object
  paths: seq[string]
  targets: seq[string]
  minWaste: int
  all, includeExtern, noSuggest, verbose, exitZero: bool
  assumed: Table[string, tuple[size, align: int]]

proc parseAssume(spec: string, opts: var Options) =
  let eq = spec.find('=')
  if eq < 0:
    quit "--assume needs TYPE=SIZE[:ALIGN], got '" & spec & "'", 2
  let name = spec[0 ..< eq].strip()
  let rest = spec[eq + 1 .. ^1].split(':')
  try:
    let size = parseInt(rest[0].strip())
    let align = if rest.len > 1: parseInt(rest[1].strip()) else: min(size, 8)
    if size < 0 or align <= 0: raise newException(ValueError, "")
    opts.assumed[simpleName(name)] = (size, align)
  except ValueError:
    quit "--assume needs integer values, got '" & spec & "'", 2

proc collect(paths: seq[string]): seq[string] =
  var seen = initHashSet[string]()
  for p in paths:
    if fileExists(p):
      if not seen.containsOrIncl(p): result.add p
    elif dirExists(p):
      for path in walkDirRec(p, relative = false):
        if path.splitFile().ext != ".pxd": continue
        if path.split(DirSep).anyIt(it in skipDirs): continue
        if not seen.containsOrIncl(path): result.add path
    else:
      stderr.writeLine "pxdpad: no such file or directory: " & p

proc rel(p: string): string =
  ## Paths under the working directory read better relative; others do not.
  try:
    let r = p.relativePath(getCurrentDir())
    if r.startsWith(".."): p else: r
  except OSError:
    p

proc holeLines(lay: Layout): string =
  for h in lay.holes:
    if h.tail:
      result.add "    " & $h.size & " bytes of tail padding at offset " &
        $h.offset & "\n"
    elif h.after.len == 0:
      result.add "    " & $h.size & " bytes of padding after the object header " &
        "(offset " & $h.offset & ")\n"
    else:
      result.add "    " & $h.size & " bytes of padding after `" & h.after &
        "` (offset " & $h.offset & ")\n"

proc sig(t: TargetResult): string =
  ## Two ABIs are worth one row when they measure the type identically. lp64 and
  ## darwin-arm64 differ only in `long double`, so they usually collapse.
  if not t.layout.complete: return "n/a"
  result = $t.layout.size & "/" & $t.suggested & "/" & $t.layout.align
  for h in t.layout.holes:
    result.add "|" & $h.offset & ":" & $h.size

proc grouped(rep: Report): seq[tuple[label: string, res: TargetResult]] =
  ## ABIs that measure alike, merged and labelled together, in the order given.
  var index = initTable[string, int]()
  for t in rep.results:
    let s = sig(t)
    if index.hasKey(s):
      result[index[s]].label.add ", " & t.target
    else:
      index[s] = result.len
      result.add (t.target, t)

proc describe(rep: Report, opts: Options, color: bool): string =
  let bold = if color: "\e[1m" else: ""
  let dim = if color: "\e[2m" else: ""
  let red = if color: "\e[31m" else: ""
  let off = if color: "\e[0m" else: ""
  let waste = rep.worstWaste
  let single = rep.results.len == 1

  result = dim & rel(rep.agg.file) & ":" & $rep.agg.line & off & "  " & bold &
    $rep.agg.kind & " " & rep.agg.name & off
  if single:
    let t = rep.results[0]
    result.add " — " & $t.layout.size & " bytes"
    if waste > 0:
      result.add ", " & red & $waste & " wasted" & off & " (" & $t.suggested &
        " optimal)"
    result.add "\n"
  else:
    let groups = grouped(rep)
    var worstGroup = 0
    for i, g in groups:
      if g.res.wasted > groups[worstGroup].res.wasted: worstGroup = i
    if waste > 0:
      result.add " — " & red & $waste & " bytes wasted" & off & " on " &
        groups[worstGroup].label & "\n"
    else:
      result.add "\n"
    var cells: seq[string] = @[]
    for g in groups:
      if not g.res.layout.complete:
        cells.add g.label & " " & dim & "n/a" & off
      elif g.res.wasted > 0:
        cells.add g.label & " " & $g.res.layout.size & red & "→" &
          $g.res.suggested & off
      else:
        cells.add g.label & " " & $g.res.layout.size
    result.add "    " & cells.join("   ") & "\n"

  # Holes differ per ABI; show them for the one with the most to gain.
  var worst = 0
  for i, t in rep.results:
    if t.wasted > rep.results[worst].wasted: worst = i
  let lay = rep.results[worst].layout
  if lay.holes.len > 0:
    if not single:
      let groups = grouped(rep)
      var label = rep.results[worst].target
      for g in groups:
        if sig(g.res) == sig(rep.results[worst]): label = g.label
      result.add "  padding on " & label & ":\n"
    result.add holeLines(lay)

  if rep.changed and not opts.noSuggest:
    result.add "  suggested order"
    if single:
      result.add " (" & $rep.results[0].suggested & " bytes)"
    else:
      result.add " — " & grouped(rep).filterIt(it.res.layout.complete)
        .mapIt(it.label & " " & $it.res.suggested).join("; ")
    result.add ":\n"
    for d in rep.order:
      result.add "    " & d.display & "\n"

proc main() =
  var opts = Options(minWaste: 1)
  for kind, key, val in getopt():
    case kind
    of cmdArgument: opts.paths.add key
    of cmdLongOption, cmdShortOption:
      case key
      of "t", "target":
        for name in val.split(','):
          if name.strip().len > 0: opts.targets.add name.strip()
      of "m", "min-waste":
        try: opts.minWaste = parseInt(val)
        except ValueError: quit "pxdpad: --min-waste needs an integer", 2
      of "a", "all": opts.all = true
      of "assume": parseAssume(val, opts)
      of "include-extern": opts.includeExtern = true
      of "no-suggest": opts.noSuggest = true
      of "v", "verbose": opts.verbose = true
      of "exit-zero": opts.exitZero = true
      of "h", "help": quit usage % [version, targetNames.join(", ")], 0
      of "V", "version": quit version, 0
      else: quit "pxdpad: unknown option --" & key, 2
    of cmdEnd: discard
  if opts.paths.len == 0: opts.paths = @[getCurrentDir()]
  if opts.targets.len == 0: opts.targets = @targetNames

  var targets: seq[Target] = @[]
  var seenTarget = initHashSet[string]()
  for name in opts.targets:
    var t: Target
    try: t = getTarget(name)
    except ValueError as e: quit "pxdpad: " & e.msg, 2
    if not seenTarget.containsOrIncl(t.name): targets.add t

  let files = collect(opts.paths)
  var pr = ParseResult()
  for f in files:
    try:
      parseFile(f, readFile(f), pr)
    except IOError:
      stderr.writeLine "pxdpad: cannot read " & f

  var resolvers: seq[Resolver] = @[]
  for t in targets:
    let r = newResolver(pr, t)
    r.assumed = opts.assumed
    resolvers.add r

  var findings, skipped: seq[Report] = @[]
  var checked, reportable = 0
  for a in pr.aggs:
    if not a.hasBody: continue
    if a.fields.len == 0 and not opts.all: continue
    if a.isExtern and not opts.includeExtern: continue
    let rep = analyzeAll(resolvers, a)
    if rep.sized == 0:
      skipped.add rep
      continue
    inc checked
    let notable = rep.worstWaste >= max(1, opts.minWaste)
    if notable: inc reportable
    if opts.all or notable: findings.add rep

  let color = isatty(stdout)
  for f in findings:
    echo describe(f, opts, color)
  var total = 0
  for f in findings: total += f.worstWaste
  echo "$1 type(s) checked across $2 ABI(s) ($3), $4 with waste, $5 byte(s) wasted" %
    [$checked, $targets.len, targets.mapIt(it.name).join(", "), $reportable, $total]
  if skipped.len > 0:
    echo "$1 type(s) skipped: a field's size is unknown (--verbose to list)" %
      [$skipped.len]
    if opts.verbose:
      for f in skipped:
        echo "  " & rel(f.agg.file) & ":" & $f.agg.line & "  " & f.agg.name &
          " — " & f.results[0].unresolved.join(", ")

  if reportable > 0 and not opts.exitZero: quit 1
  quit 0

when isMainModule:
  main()
