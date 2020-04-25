set destdir=%1
set ffmpeg_version=4.2.2
set ffmpeg_basename=ffmpeg-%ffmpeg_version%-win%PYTHON_ARCH%
set outputdir=output

for %%d in (%destdir% %ffmpeg_basename%-dev %ffmpeg_basename%-shared) do (
    if exist %%d (
        rmdir /s /q %%d
    )
)

set outputfile=%outputdir%\ffmpeg-%ffmpeg_version%-win%PYTHON_ARCH%.tar.bz2

if not exist %outputdir% (
    mkdir %outputdir%
)
if not exist %outputfile% (
    mkdir %destdir%

    if not exist %ffmpeg_basename%-dev.zip (
        curl -L -o %ffmpeg_basename%-dev.zip https://ffmpeg.zeranoe.com/builds/win%PYTHON_ARCH%/dev/%ffmpeg_basename%-dev.zip
    )
    unzip %ffmpeg_basename%-dev.zip
    mkdir %destdir%\include
    xcopy %ffmpeg_basename%-dev\include %destdir%\include /E
    mkdir %destdir%\lib
    xcopy %ffmpeg_basename%-dev\lib %destdir%\lib /E

    if not exist %ffmpeg_basename%-shared.zip (
        curl -L -o %ffmpeg_basename%-shared.zip https://ffmpeg.zeranoe.com/builds/win%PYTHON_ARCH%/shared/%ffmpeg_basename%-shared.zip
    )
    unzip %ffmpeg_basename%-shared.zip
    mkdir %destdir%\bin
    xcopy %ffmpeg_basename%-shared\bin %destdir%\bin\ /E

    tar cjvf %outputfile% -C %destdir% bin include lib
)
