"""Run ``auditwheel`` for a foreign architecture/libc from an x86_64 host.

auditwheel builds its ``--plat`` choices from the host's detected architecture
and libc, so on an x86_64 runner it rejects e.g. ``manylinux_2_31_armv7l``. The
repair logic itself re-derives the architecture and libc from the wheel and works
cross-arch, so we only need to override the host detection used to build the CLI
choice list.

Usage::

    python auditwheel-cross.py <arch> <glibc|musl> <auditwheel args...>
"""

import sys

from auditwheel.architecture import Architecture
from auditwheel.libc import Libc

_arch = Architecture(sys.argv[1])
_libc = {"glibc": Libc.GLIBC, "musl": Libc.MUSL}[sys.argv[2]]
del sys.argv[1:3]

Architecture.detect = staticmethod(lambda *, bits=None: _arch)
Libc.detect = staticmethod(lambda: _libc)

from auditwheel.main import main  # noqa: E402  (import after patching detection)

sys.exit(main())
