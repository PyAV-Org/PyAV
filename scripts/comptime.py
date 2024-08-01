import os
import sys

def replace_in_file(file_path):
    try:
        with open(file_path, "r", encoding="utf-8") as file:
            content = file.read()

        modified_content = content.replace("# [FFMPEG6] ", "")

        with open(file_path, "w") as file:
            file.write(modified_content)
    except UnicodeDecodeError:
        pass


def process_directory(directory):
    for root, dirs, files in os.walk(directory):
        for file in files:
            file_path = os.path.join(root, file)
            replace_in_file(file_path)


version = os.environ.get("PYAV_LIBRARY")
if version is None:
    is_6 = sys.argv[1].startswith("6")
else:
    is_6 = version.startswith("ffmpeg-6")

if is_6:
    process_directory("av")
    process_directory("include")
