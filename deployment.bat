REM Change --ffmpeg-dir argument as necessary
python setup.py clean --all build_ext --inplace --ffmpeg-dir=C:\work\ffmpeg-4.0-win64-dev -c msvc
pip wheel .
