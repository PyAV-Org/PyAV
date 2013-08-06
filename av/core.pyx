cimport libav as lib

lib.avcodec_register_all()
lib.av_register_all()
lib.avfilter_register_all()