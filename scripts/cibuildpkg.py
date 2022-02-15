# Utilities for building native library inside cibuildwheel

import contextlib
import os
import platform
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile
import time
from dataclasses import dataclass, field
from typing import Dict, List


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
def chdir(path):
    """
    Changes to a directory and returns to the original directory at exit.
    """
    cwd = os.getcwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(cwd)


@contextlib.contextmanager
def log_group(title):
    """
    Starts a log group and ends it at exit.
    """
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


def prepend_env(env, name, new, separator=" "):
    old = env.get(name)
    if old:
        env[name] = new + separator + old
    else:
        env[name] = new


def run(cmd, env=None):
    sys.stdout.write(f"- Running: {cmd}\n")
    sys.stdout.flush()
    subprocess.run(cmd, check=True, env=env)


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
        self._builder_dest_dir = dest_dir + ".builder"
        self._target_dest_dir = dest_dir

        self.build_dir = os.path.abspath("build")
        self.patch_dir = os.path.abspath("patches")
        self.source_dir = os.path.abspath("source")

    def build(self, package: Package, *, for_builder: bool = False):
        with log_group(f"build {package.name}"):
            self._extract(package)
            if package.build_system == "cmake":
                self._build_with_cmake(package, for_builder=for_builder)
            elif package.build_system == "meson":
                self._build_with_meson(package, for_builder=for_builder)
            else:
                self._build_with_autoconf(package, for_builder=for_builder)

    def create_directories(self):
        # create directories
        for d in [self.build_dir, self._builder_dest_dir, self._target_dest_dir]:
            if os.path.exists(d):
                shutil.rmtree(d)
        for d in [self.build_dir, self.source_dir]:
            if not os.path.exists(d):
                os.mkdir(d)

        # add tools to PATH
        prepend_env(
            os.environ,
            "PATH",
            os.path.join(self._builder_dest_dir, "bin"),
            separator=":",
        )

    def _build_with_autoconf(self, package: Package, for_builder: bool) -> None:
        assert package.build_system == "autoconf"
        package_path = os.path.join(self.build_dir, package.name)
        package_source_path = os.path.join(package_path, package.source_dir)
        package_build_path = os.path.join(package_path, package.build_dir)

        # determine configure arguments
        env = self._environment(for_builder=for_builder)
        prefix = self._prefix(for_builder=for_builder)
        configure_args = [
            "--disable-static",
            "--enable-shared",
            "--libdir=" + os.path.join(prefix, "lib"),
            "--prefix=" + prefix,
        ]

        # build package
        os.makedirs(package_build_path, exist_ok=True)
        with chdir(package_build_path):
            run(
                [os.path.join(package_source_path, "configure")]
                + configure_args
                + package.build_arguments,
                env=env,
            )
            run(["make"] + make_args(parallel=package.build_parallel), env=env)
            run(["make", "install"], env=env)

    def _build_with_cmake(self, package: Package, for_builder: bool) -> None:
        assert package.build_system == "cmake"
        package_path = os.path.join(self.build_dir, package.name)
        package_source_path = os.path.join(package_path, package.source_dir)
        package_build_path = os.path.join(package_path, package.build_dir)

        # determine cmake arguments
        env = self._environment(for_builder=for_builder)
        prefix = self._prefix(for_builder=for_builder)
        cmake_args = [
            "-DBUILD_SHARED_LIBS=1",
            "-DCMAKE_INSTALL_LIBDIR=lib",
            "-DCMAKE_INSTALL_PREFIX=" + prefix,
        ]
        if platform.system() == "Darwin":
            cmake_args.append("-DCMAKE_INSTALL_NAME_DIR=" + os.path.join(prefix, "lib"))

        # build package
        os.makedirs(package_build_path, exist_ok=True)
        with chdir(package_build_path):
            run(
                ["cmake", package_source_path] + cmake_args + package.build_arguments,
                env=env,
            )
            run(["make"] + make_args(parallel=package.build_parallel), env=env)
            run(["make", "install"], env=env)

    def _build_with_meson(self, package: Package, for_builder: bool) -> None:
        assert package.build_system == "meson"
        package_path = os.path.join(self.build_dir, package.name)
        package_source_path = os.path.join(package_path, package.source_dir)
        package_build_path = os.path.join(package_path, package.build_dir)

        # determine meson arguments
        env = self._environment(for_builder=for_builder)
        prefix = self._prefix(for_builder=for_builder)
        meson_args = ["--libdir=lib", "--prefix=" + prefix]

        # build package
        os.makedirs(package_build_path, exist_ok=True)
        with chdir(package_build_path):
            run(
                ["meson", package_source_path] + meson_args + package.build_arguments,
                env=env,
            )
            run(["ninja"], env=env)
            run(["ninja", "install"], env=env)

    def _extract(self, package: Package) -> None:
        assert package.source_strip_components in (
            0,
            1,
        ), "source_strip_components must be 0 or 1"
        path = os.path.join(self.build_dir, package.name)
        patch = os.path.join(self.patch_dir, package.name + ".patch")
        tarball = os.path.join(self.source_dir, package.source_url.split("/")[-1])

        # download tarball
        if not os.path.exists(tarball):
            run(["curl", "-L", "-o", tarball, package.source_url])

        with tarfile.open(tarball) as tar:
            # determine common prefix to strip
            if package.source_strip_components:
                prefixes = set()
                for name in tar.getnames():
                    prefixes.add(name.split("/")[0])
                assert (
                    len(prefixes) == 1
                ), "cannot strip path components, multiple prefixes found"
                prefix = list(prefixes)[0]
            else:
                prefix = ""

            # extract archive
            with tempfile.TemporaryDirectory() as temp_dir:
                tar.extractall(temp_dir)
                temp_subdir = os.path.join(temp_dir, prefix)
                shutil.move(temp_subdir, path)

        # apply patch
        if os.path.exists(patch):
            run(["patch", "-d", path, "-i", patch, "-p1"])

    def _environment(self, *, for_builder: bool) -> Dict[str, str]:
        env = os.environ.copy()

        prefix = self._prefix(for_builder=for_builder)
        prepend_env(env, "CPPFLAGS", "-I" + os.path.join(prefix, "include"))
        prepend_env(env, "LDFLAGS", "-L" + os.path.join(prefix, "lib"))
        prepend_env(
            env,
            "PKG_CONFIG_PATH",
            os.path.join(prefix, "lib", "pkgconfig"),
            separator=":",
        )

        return env

    def _prefix(self, *, for_builder: bool) -> str:
        if for_builder:
            return self._builder_dest_dir
        else:
            return self._target_dest_dir
