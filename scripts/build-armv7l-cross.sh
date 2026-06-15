#! /usr/bin/env bash
#
# Cross-compile PyAV's armv7l (32-bit ARM) wheels with zig on an x86_64 host,
# without QEMU. Only PyAV's Cython->C extensions are compiled; FFmpeg is fetched
# prebuilt for armv7l. zig is the cross compiler, and CPython's cross-build env
# vars (_PYTHON_HOST_PLATFORM / _PYTHON_SYSCONFIGDATA_NAME) make sysconfig report
# armv7l without running any armv7l code. The target Python trees + system libs
# are copied out of the manylinux armv7l image with `docker cp` (no execution).
#
# Builds two manylinux (glibc) wheels: cp311-abi3 (covers 3.11-3.13) and cp314t.
# musllinux armv7l is skipped: the musl FFmpeg needs system libs (libdrm,
# libxcb*, libbz2) the musllinux image doesn't ship for auditwheel to bundle.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
cd "$root"

# Host interpreters that drive each build (must match the wheel's Python: 3.11
# emits cp311-abi3, 3.14t emits cp314t). zig/auditwheel run from TOOLS_PY.
HOST_PY311="${HOST_PY311:-python3.11}"
HOST_PY314T="${HOST_PY314T:-python3.14t}"
TOOLS_PY="${TOOLS_PY:-python3}"

DIST_DIR="${DIST_DIR:-$root/dist}"
WORK_DIR="${WORK_DIR:-$root/build/armv7l-cross}"
IMAGE="quay.io/pypa/manylinux_2_31_armv7l"
TRIPLE="arm-linux-gnueabihf.2.31"  # pin glibc to the manylinux_2_31 policy
PLAT="manylinux_2_31_armv7l"
FFMPEG_CONFIG="scripts/ffmpeg-latest.json"

PY_DIR="$WORK_DIR/py"
BIN_DIR="$WORK_DIR/bin"
mkdir -p "$DIST_DIR" "$BIN_DIR" "$PY_DIR"

# --- zig compiler wrappers ------------------------------------------------
# setuptools invokes $CC / $LDSHARED as plain commands. Resolve the zig binary
# once and call it directly (not "python -m ziglang"): the build sets PYTHONPATH
# to the target stdlib, which would crash a per-compile Python. The wrappers also
# drop a few gcc-only flags clang (zig) rejects.
ZIG_BIN="$("$TOOLS_PY" -c 'import os, ziglang; print(os.path.join(os.path.dirname(ziglang.__file__), "zig"))')"

write_cc() {
    cat >"$1" <<EOF
#! /usr/bin/env bash
args=()
for a in "\$@"; do
    case "\$a" in
        -fno-semantic-interposition|-fstack-clash-protection|-fcf-protection*|-mno-cet|-march=native|-mtune=native|--param=*|-fipa-pta) ;;
        *) args+=("\$a") ;;
    esac
done
exec "$ZIG_BIN" $2 -target "$TRIPLE" "\${args[@]}"
EOF
    chmod +x "$1"
}
write_cc "$BIN_DIR/zig-cc" cc
write_cc "$BIN_DIR/zig-cxx" c++
printf '#! /usr/bin/env bash\nexec "%s" ar "$@"\n' "$ZIG_BIN" >"$BIN_DIR/zig-ar"
chmod +x "$BIN_DIR/zig-ar"

# --- copy the target Python trees + system libs out of the image ----------
extract_image() {
    if [[ -d "$PY_DIR/_internal" ]]; then
        return  # already extracted
    fi
    echo "Pulling $IMAGE"
    docker pull --platform linux/arm/v7 "$IMAGE"
    local cid
    cid="$(docker create --platform linux/arm/v7 "$IMAGE")"
    # /opt/python/<tag> are symlinks into /opt/_internal/<tree>; copy both. Also
    # grab the armhf system libs (libxcb, ...) FFmpeg needs so auditwheel can
    # bundle them. docker cp reads the filesystem; it runs no armv7l code.
    docker cp "$cid:/opt/python" "$PY_DIR"
    docker cp "$cid:/opt/_internal" "$PY_DIR"
    docker cp "$cid:/usr/lib/arm-linux-gnueabihf" "$PY_DIR/syslib"
    docker rm -f "$cid" >/dev/null
}

# --- build + repair one wheel ---------------------------------------------
# args: <host_py> <python-tag-glob>
build_one() {
    local host_py="$1" py_glob="$2"

    # Resolve /opt/python/<tag> symlink to its real tree under /opt/_internal.
    local link
    link="$(find "$PY_DIR/python" -maxdepth 1 -name "$py_glob" | head -1)"
    [[ -n "$link" ]] || { echo "no python matching '$py_glob':" >&2; ls "$PY_DIR/python" >&2; exit 1; }
    local pytree="$PY_DIR/_internal/$(basename "$(readlink "$link")")"

    local inc=( "$pytree"/include/python3.* )
    local scd=( "$pytree"/lib/python3.*/_sysconfigdata_*.py )
    echo "=== building for $(basename "$pytree") (host $host_py) ==="

    # FFmpeg's pkg-config files bake in prefix=/tmp/vendor, so extract there.
    rm -rf /tmp/vendor
    PYAV_VENDOR_PLATFORM=manylinux-armv7l "$TOOLS_PY" scripts/fetch-vendor.py \
        --config-file "$FFMPEG_CONFIG" /tmp/vendor

    local raw="$WORK_DIR/raw/$(basename "$pytree")"
    rm -rf "$raw"; mkdir -p "$raw"

    # The _PYTHON_* vars make sysconfig report armv7l; zig does the compiling.
    # max-page-size=4096 aligns our extensions to the armv7l (4K) page size;
    # lld's default 64K alignment uses 4K file offsets, which the loader rejects.
    env \
        CC="$BIN_DIR/zig-cc" CXX="$BIN_DIR/zig-cxx" AR="$BIN_DIR/zig-ar" \
        LDSHARED="$BIN_DIR/zig-cc -shared -Wl,-z,max-page-size=4096" \
        _PYTHON_HOST_PLATFORM=linux-armv7l \
        _PYTHON_SYSCONFIGDATA_NAME="$(basename "${scd[0]}" .py)" \
        PYTHONPATH="$(dirname "${scd[0]}")" \
        CFLAGS="-I${inc[0]} -Wno-error=incompatible-pointer-types" \
        PKG_CONFIG_PATH=/tmp/vendor/lib/pkgconfig \
        LD_LIBRARY_PATH=/tmp/vendor/lib \
        "$host_py" -m pip wheel . --no-build-isolation --no-deps -w "$raw"

    # Bundle FFmpeg + its armhf system deps and stamp the platform tag. The shim
    # lets auditwheel accept the armv7l --plat from an x86_64 host; --ldpaths
    # points it at the target's libs instead of the host search path. Force the
    # pip patchelf (<0.18, on PATH via the scripts dir) ahead of the system one:
    # ubuntu-24.04 ships patchelf 0.18.0, which silently corrupts ELF files with
    # large p_align, breaking the bundled FFmpeg libs at runtime.
    local pe_dir
    pe_dir="$("$TOOLS_PY" -c 'import sysconfig; print(sysconfig.get_path("scripts"))')"
    PATH="$pe_dir:$PATH" "$TOOLS_PY" scripts/auditwheel-cross.py armv7l glibc repair \
        --ldpaths "/tmp/vendor/lib:$PY_DIR/syslib" \
        --plat "$PLAT" -w "$DIST_DIR" "$raw"/*.whl
}

extract_image
build_one "$HOST_PY311" "cp311-cp311"
build_one "$HOST_PY314T" "cp314*-cp314t"

echo
echo "Built armv7l wheels:"
ls -1 "$DIST_DIR"/*armv7l*.whl
