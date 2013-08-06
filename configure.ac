AC_INIT([PyAV], [1.0], [pyav@mikeboers.com])

# The libraries we will link against.
AV_LIBS="libavformat libavcodec libavutil libswscale libswresample libavfilter"

# Grab the CFLAGS and LDFLAGS for those libraries.
AV_CFLAGS=`pkg-config --cflags ${AV_LIBS}`
AC_SUBST(AV_CFLAGS)
AV_LDFLAGS=`pkg-config --libs ${AV_LIBS}`
AC_SUBST(AV_LDFLAGS)

# Setup tests from here to link against our libraries.
LDFLAGS="${LDFLAGS} ${AV_LDFLAGS}"

# Look for some of the differences between FFmpeg and Libav. These will result
# in HAVE_<FUNC_NAME> macros to be defined.
AC_CHECK_FUNCS_ONCE(av_frame_get_best_effort_timestamp)
AC_CHECK_FUNCS_ONCE(avformat_close_input)

AC_CONFIG_FILES([
    config.py
])

AC_OUTPUT
