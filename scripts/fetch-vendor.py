import argparse
import logging
import json
import os
import platform
import struct
import subprocess


def get_platform():
    system = platform.system()
    machine = platform.machine()
    if system == "Linux":
        if platform.libc_ver()[0] == "glibc":
            return f"manylinux_{machine}"
        else:
            return f"musllinux_{machine}"
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


parser = argparse.ArgumentParser(description="Fetch and extract tarballs")
parser.add_argument("destination_dir")
parser.add_argument("--cache-dir", default="tarballs")
parser.add_argument("--config-file", default=os.path.splitext(__file__)[0] + ".json")
args = parser.parse_args()
logging.basicConfig(level=logging.INFO)

with open(args.config_file) as fp:
    config = json.load(fp)

# ensure destination directory exists
logging.info(f"Creating directory {args.destination_dir}")
if not os.path.exists(args.destination_dir):
    os.makedirs(args.destination_dir)

tarball_url = config["url"].replace("{platform}", get_platform())

# download tarball
tarball_name = tarball_url.split("/")[-1]
tarball_file = os.path.join(args.cache_dir, tarball_name)
if not os.path.exists(tarball_file):
    logging.info(f"Downloading {tarball_url}")
    if not os.path.exists(args.cache_dir):
        os.mkdir(args.cache_dir)
    subprocess.check_call(
        ["curl", "--location", "--output", tarball_file, "--silent", tarball_url]
    )

# extract tarball
logging.info(f"Extracting {tarball_name}")
subprocess.check_call(["tar", "-C", args.destination_dir, "-xf", tarball_file])
