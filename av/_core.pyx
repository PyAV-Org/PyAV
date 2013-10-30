cimport libav as lib

# Setup base library.
lib.av_register_all()

# Exports.
time_base = lib.AV_TIME_BASE
