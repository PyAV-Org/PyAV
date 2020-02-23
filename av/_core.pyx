cimport libav as lib


# Initialise libraries.
lib.avformat_network_init()
lib.avdevice_register_all()

# Exports.
time_base = lib.AV_TIME_BASE

pyav_version = lib.PYAV_VERSION_STR
pyav_commit = lib.PYAV_COMMIT_STR


cdef decode_version(v):
    if v < 0:
        return (-1, -1, -1)
    cdef int major = (v >> 16) & 0xff
    cdef int minor = (v >> 8) & 0xff
    cdef int micro = (v) & 0xff
    return (major, minor, micro)

library_meta = {
    'libavutil': dict(
        version=decode_version(lib.avutil_version()),
        configuration=lib.avutil_configuration(),
        license=lib.avutil_license()
    ),
    'libavcodec': dict(
        version=decode_version(lib.avcodec_version()),
        configuration=lib.avcodec_configuration(),
        license=lib.avcodec_license()
    ),
    'libavformat': dict(
        version=decode_version(lib.avformat_version()),
        configuration=lib.avformat_configuration(),
        license=lib.avformat_license()
    ),
    'libavdevice': dict(
        version=decode_version(lib.avdevice_version()),
        configuration=lib.avdevice_configuration(),
        license=lib.avdevice_license()
    ),
    'libavfilter': dict(
        version=decode_version(lib.avfilter_version()),
        configuration=lib.avfilter_configuration(),
        license=lib.avfilter_license()
    ),
    'libswscale': dict(
        version=decode_version(lib.swscale_version()),
        configuration=lib.swscale_configuration(),
        license=lib.swscale_license()
    ),
    'libswresample': dict(
        version=decode_version(lib.swresample_version()),
        configuration=lib.swresample_configuration(),
        license=lib.swresample_license()
    ),
}

library_versions = {name: meta['version'] for name, meta in library_meta.items()}
