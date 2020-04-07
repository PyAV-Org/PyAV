
#include "libavcodec/version.h"

#if LIBAVCODEC_VERSION_MAJOR < 58
#error PyAV v7.0 requires FFmpeg v4.0 or higher; please install PyAV v6.2 for FFmpeg < v4.0.
#endif
