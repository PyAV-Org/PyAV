cimport libav as lib

# Setup base library.
lib.av_register_all()
lib.avformat_network_init()
lib.avdevice_register_all()

# Exports.
time_base = lib.AV_TIME_BASE
