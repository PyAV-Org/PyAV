AC_INIT([PyAV], [1.0], [pyav@mikeboers.com])

AV_LIBS="libavformat libavcodec libavutil libswscale"
AV_CFLAGS=`pkg-config --cflags ${AV_LIBS}`
AC_SUBST(AV_CFLAGS)
AV_LDFLAGS=`pkg-config --libs ${AV_LIBS}`
AC_SUBST(AV_LDFLAGS)

LDFLAGS="${LDFLAGS} ${AV_LDFLAGS}"

AC_CHECK_FUNCS_ONCE(av_new_stream)
AC_CHECK_FUNCS_ONCE(av_frame_get_best_effort_timestamp)
AC_CHECK_FUNCS_ONCE(avformat_close_input)

AC_CONFIG_FILES([
    config.py
])

AC_OUTPUT
