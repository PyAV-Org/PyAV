set destdir=%1
set ffmpeg_version=4.3.2-2021-02-27
set ffmpeg_dirname=ffmpeg-%ffmpeg_version%-full_build-shared
set ffmpeg_zipname=ffmpeg-%ffmpeg_version%-full_build-shared.7z
set outputdir=output

for %%d in (%destdir% %ffmpeg_dirname%) do (
    if exist %%d (
        rmdir /s /q %%d
    )
)

set outputfile=%outputdir%\ffmpeg-win%PYTHON_ARCH%.tar.gz

if not exist %outputdir% (
    mkdir %outputdir%
)
if not exist %outputfile% (
    mkdir %destdir%

    if not exist %ffmpeg_zipname% (
        curl -L -o %ffmpeg_zipname% https://github.com/GyanD/codexffmpeg/releases/download/%ffmpeg_version%/%ffmpeg_zipname%
    )
    7z x %ffmpeg_zipname%
    mkdir %destdir%\bin
    xcopy %ffmpeg_dirname%\bin %destdir%\bin /E
    mkdir %destdir%\include
    xcopy %ffmpeg_dirname%\include %destdir%\include /E
    mkdir %destdir%\lib
    xcopy %ffmpeg_dirname%\lib %destdir%\lib /E

    tar czvf %outputfile% -C %destdir% bin include lib
)
