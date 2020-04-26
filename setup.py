import setuptools
import sys

if sys.platform == "win32":
    include_dirs = ["C:\\cibw\\vendor\\include"]
    library_dirs = ["C:\\cibw\\vendor\\lib"]
else:
    include_dirs = ["/tmp/vendor/include"]
    library_dirs = ["/tmp/vendor/lib"]

setuptools.setup(
    name="dummy",
    package_dir={"": "src"},
    packages=["dummy"],
    ext_modules=[
        setuptools.Extension(
            "dummy.binding",
            include_dirs=include_dirs,
            library_dirs=library_dirs,
            libraries=[
                "avformat",
                "avcodec",
                "avdevice",
                "avutil",
                "avfilter",
                "swscale",
                "swresample",
            ],
            sources=["src/dummy/binding.c"],
        ),
    ],
)
