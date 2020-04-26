#!/usr/bin/env python

import argparse
import logging
import os
import shutil
import zipfile

parser = argparse.ArgumentParser(description="Inject DLLs into a Windows binary wheel")
parser.add_argument(
    "wheel", type=str, help="the source wheel to which DLLs should be added",
)
parser.add_argument(
    "dest_dir", type=str, help="the directory where to create the repaired wheel",
)
parser.add_argument(
    "dll_dir", type=str, help="the directory containing the DLLs",
)

args = parser.parse_args()
wheel_name = os.path.basename(args.wheel)
package_name = wheel_name.split("-")[0]
repaired_wheel = os.path.join(args.dest_dir, wheel_name)

logging.basicConfig(level=logging.INFO)
logging.info("Copying '%s' to '%s'", args.wheel, repaired_wheel)
shutil.copy(args.wheel, repaired_wheel)

logging.info("Adding DLLs from '%s' to package '%s'", args.dll_dir, package_name)
with zipfile.ZipFile(repaired_wheel, mode="a", compression=zipfile.ZIP_DEFLATED) as wheel:
    for name in sorted(os.listdir(args.dll_dir)):
        if name.lower().endswith(".dll"):
            local_path = os.path.join(args.dll_dir, name)
            archive_path = os.path.join(package_name, name)
            if archive_path not in wheel.namelist():
                logging.info("Adding '%s' as '%s'", local_path, archive_path)
                wheel.write(local_path, archive_path)
