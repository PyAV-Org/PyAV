AC_INIT([PyAV], [1.0], [pyav@mikeboers.com])

# The libraries we will link against.

AC_ARG_WITH([avresample], [  --with-avresample       use libavresample instead of libswresample],[with_avresample=yes])

AV_LIBS="libavformat libavcodec libavutil libswscale"

# Prefer libswresample but use libavresample if can't find it
if test "$with_avresample" == "yes"
then
AC_MSG_NOTICE([using libavresample])
AV_LIBS="${AV_LIBS} libavresample"
AC_DEFINE(USE_AVRESAMPLE,1)

elif pkg-config --exists libswresample
then
AC_MSG_NOTICE([using libswresample])
AV_LIBS="${AV_LIBS} libswresample"

else
AC_MSG_NOTICE([using libswresample])
AV_LIBS="${AV_LIBS} libavresample"
AC_DEFINE(USE_AVRESAMPLE,1)
fi

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
