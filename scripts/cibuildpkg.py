# Utilities for building native library inside cibuildwheel

import contextlib
import os
import platform
import shutil
import struct
import subprocess
import sys
import time
from dataclasses import dataclass, field
from typing import List


def get_platform():
    """
    Get the current platform tag.
    """
    system = platform.system()
    machine = platform.machine()
    if system == "Linux":
        return f"manylinux_{machine}"
    elif system == "Darwin":
        # cibuildwheel sets ARCHFLAGS:
        # https://github.com/pypa/cibuildwheel/blob/5255155bc57eb6224354356df648dc42e31a0028/cibuildwheel/macos.py#L207-L220
        if "ARCHFLAGS" in os.environ:
            machine = os.environ["ARCHFLAGS"].split()[1]
        return f"macosx_{machine}"
    elif system == "Windows":
        if struct.calcsize("P") * 8 == 64:
            return "win_amd64"
        else:
            return "win32"
    else:
        raise Exception(f"Unsupported system {system}")


@contextlib.contextmanager
def log_group(title):
    start_time = time.time()
    success = False
    sys.stdout.write(f"::group::{title}\n")
    sys.stdout.flush()
    try:
        yield
        success = True
    finally:
        duration = time.time() - start_time
        outcome = "ok" if success else "failed"
        start_color = "\033[32m" if success else "\033[31m"
        end_color = "\033[0m"
        sys.stdout.write("::endgroup::\n")
        sys.stdout.write(
            f"{start_color}{outcome}{end_color} {duration:.2f}s\n".rjust(78)
        )
        sys.stdout.flush()


def make_args(*, parallel: bool) -> List[str]:
    """
    Arguments for GNU make.
    """
    args = []

    # do not parallelize build when running in qemu
    if parallel and platform.machine() != "aarch64":
        args.append("-j")

    return args


def prepend_env(name, new, separator=" "):
    old = os.environ.get(name)
    if old:
        os.environ[name] = new + separator + old
    else:
        os.environ[name] = new


def run(cmd):
    sys.stdout.write(f"- Running: {cmd}\n")
    sys.stdout.flush()
    subprocess.run(cmd, check=True)


@dataclass
class Package:
    name: str
    source_url: str
    build_system: str = "autoconf"
    build_arguments: List[str] = field(default_factory=list)
    build_dir: str = "build"
    build_parallel: bool = True
    requires: List[str] = field(default_factory=list)
    source_dir: str = ""
    source_strip_components: int = 1


class Builder:
    def __init__(self, dest_dir: str) -> None:
        self.dest_dir = dest_dir
        self.build_dir = os.path.abspath("build")
        self.patch_dir = os.path.abspath("patches")
        self.source_dir = os.path.abspath("source")

    def build(
        self,
        package: Package,
    ):
        with log_group(f"build {package.name}"):
            self._extract(package)
            if package.build_system == "cmake":
                self._build_with_cmake(package)
            elif package.build_system == "meson":
                self._build_with_meson(package)
            else:
                self._build_with_autoconf(package)

    def create_directories(self):
        for d in [self.build_dir, self.dest_dir]:
            if os.path.exists(d):
                shutil.rmtree(d)
        for d in [self.build_dir, self.source_dir]:
            if not os.path.exists(d):
                os.mkdir(d)

    def _build_with_autoconf(self, package: Package) -> None:
        assert package.build_system == "autoconf"
        package_path = os.path.join(self.build_dir, package.name)
        package_source_path = os.path.join(package_path, package.source_dir)
        package_build_path = os.path.join(package_path, package.build_dir)

        # build package
        os.makedirs(package_build_path, exist_ok=True)
        os.chdir(package_build_path)
        run(
            [os.path.join(package_source_path, "configure")]
            + [
                "--disable-static",
                "--enable-shared",
                "--libdir=" + os.path.join(self.dest_dir, "lib"),
                "--prefix=" + self.dest_dir,
            ]
            + package.build_arguments
        )
        run(["make"] + make_args(parallel=package.build_parallel))
        run(["make", "install"])
        os.chdir(self.build_dir)

    def _build_with_cmake(self, package: Package) -> None:
        assert package.build_system == "cmake"
        package_path = os.path.join(self.build_dir, package.name)
        package_source_path = os.path.join(package_path, package.source_dir)
        package_build_path = os.path.join(package_path, package.build_dir)

        # determine cmake arguments
        cmake_args = [
            "-DBUILD_SHARED_LIBS=1",
            "-DCMAKE_INSTALL_LIBDIR=lib",
            "-DCMAKE_INSTALL_PREFIX=" + self.dest_dir,
        ]
        if platform.system() == "Darwin":
            cmake_args.append(
                "-DCMAKE_INSTALL_NAME_DIR=" + os.path.join(self.dest_dir, "lib")
            )

        # build package
        os.makedirs(package_build_path, exist_ok=True)
        os.chdir(package_build_path)
        run(["cmake", package_source_path] + cmake_args + package.build_arguments)
        run(["make"] + make_args(parallel=package.build_parallel))
        run(["make", "install"])
        os.chdir(self.build_dir)

    def _build_with_meson(self, package: Package) -> None:
        assert package.build_system == "meson"
        package_path = os.path.join(self.build_dir, package.name)
        package_source_path = os.path.join(package_path, package.source_dir)
        package_build_path = os.path.join(package_path, package.build_dir)

        # build package
        os.makedirs(package_build_path, exist_ok=True)
        os.chdir(package_build_path)
        run(["meson", package_source_path, "--libdir=lib", "--prefix=" + self.dest_dir])
        run(["ninja"])
        run(["ninja", "install"])
        os.chdir(self.build_dir)

    def _extract(self, package: Package) -> None:
        path = os.path.join(self.build_dir, package.name)
        patch = os.path.join(self.patch_dir, package.name + ".patch")
        tarball = os.path.join(self.source_dir, package.source_url.split("/")[-1])

        # download tarball
        if not os.path.exists(tarball):
            run(["curl", "-L", "-o", tarball, package.source_url])

        # extract tarball
        os.mkdir(path)
        run(
            [
                "tar",
                "xf",
                tarball,
                "-C",
                path,
                "--strip-components",
                str(package.source_strip_components),
            ]
        )

        # apply patch
        if os.path.exists(patch):
            run(["patch", "-d", path, "-i", patch, "-p1"])
