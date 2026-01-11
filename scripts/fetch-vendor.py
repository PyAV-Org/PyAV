import argparse
import logging
import json
import os
import platform
import struct
import subprocess


def get_platform():
    system = platform.system()
    machine = platform.machine().lower()
    is_arm64 = machine in {"arm64", "aarch64"}
    if system == "Linux":
        prefix = "manylinux-" if platform.libc_ver()[0] == "glibc" else "musllinux-"
        return prefix + machine
    elif system == "Darwin":
        return "macos-arm64" if is_arm64 else "macos-x86_64"
    elif system == "Windows":
        return "windows-aarch64" if is_arm64 else "windows-x86_64"
    else:
        return "unknown"


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

logging.info(f"Extracting {tarball_name}")
subprocess.check_call(["tar", "-C", args.destination_dir, "-xf", tarball_file])
