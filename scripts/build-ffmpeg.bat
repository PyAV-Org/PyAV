set destdir=%1
set version=ffmpeg-4.2.2-win%PYTHON_ARCH%-dev

for %%d in (%destdir% %version%) do (
    if exist %%d (
        rmdir /s /q %%d
    )
)

if not exist %version%.zip (
    curl -L -o %version%.zip https://ffmpeg.zeranoe.com/builds/win%PYTHON_ARCH%/dev/%version%.zip
)
unzip %version%.zip

mkdir %destdir%
xcopy %version% %destdir%\ /E
