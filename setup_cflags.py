import argparse
import shlex

# GNU ld spellings FFmpeg writes into .pc Libs: when configured with --enable-rpath.
_WL_RPATH_PREFIXES = ("-Wl,-rpath,", "-Wl,-rpath=")


def _rpath_from_wl_flag(flag):
    """Return a path from a GNU rpath linker flag, or None."""
    for prefix in _WL_RPATH_PREFIXES:
        if flag.startswith(prefix):
            path = flag[len(prefix) :]
            if path:
                return path
    return None


def _unique(items):
    seen = set()
    unique = []
    for item in items:
        if item not in seen:
            seen.add(item)
            unique.append(item)
    return unique


def parse_cflags(raw_flags):
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("-I", dest="include_dirs", action="append")
    parser.add_argument("-L", dest="library_dirs", action="append")
    parser.add_argument("-l", dest="libraries", action="append")
    parser.add_argument("-D", dest="define_macros", action="append")
    parser.add_argument("-R", dest="runtime_library_dirs", action="append")

    raw_args = shlex.split(raw_flags.strip())
    args, unknown = parser.parse_known_args(raw_args)
    config = {k: v or [] for k, v in args.__dict__.items()}
    for i, x in enumerate(config["define_macros"]):
        parts = x.split("=", 1)
        value = x[1] or None if len(x) == 2 else None
        config["define_macros"][i] = (parts[0], value)

    remaining_unknown = []
    rpaths = list(config["runtime_library_dirs"])
    for flag in unknown:
        path = _rpath_from_wl_flag(flag)
        if path is not None:
            rpaths.append(path)
        else:
            remaining_unknown.append(flag)

    config["runtime_library_dirs"] = _unique(rpaths)
    return config, " ".join(shlex.quote(x) for x in remaining_unknown)
