cimport libav as lib

# Setup base library.
lib.av_register_all()
lib.avformat_network_init()

# Exports.
time_base = lib.AV_TIME_BASE
