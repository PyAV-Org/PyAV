from cython.operator cimport dereference
from libc.stdint cimport int64_t
from libc.stdlib cimport free, malloc

import os
import time

cimport libav as lib

from av.container.core cimport timeout_info
from av.container.input cimport InputContainer
from av.container.output cimport OutputContainer
from av.container.pyio cimport pyio_close_custom_gil, pyio_close_gil
from av.enum cimport define_enum
from av.error cimport err_check, stash_exception
from av.format cimport build_container_format
from av.utils cimport avdict_to_dict

from av.dictionary import Dictionary
from av.logging import Capture as LogCapture


ctypedef int64_t (*seek_func_t)(void *opaque, int64_t offset, int whence) nogil


cdef object _cinit_sentinel = object()


# We want to use the monotonic clock if it is available.
cdef object clock = getattr(time, 'monotonic', time.time)

cdef int interrupt_cb (void *p) nogil:

    cdef timeout_info info = dereference(<timeout_info*> p)
    if info.timeout < 0:  # timeout < 0 means no timeout
        return 0

    cdef double current_time
    with gil:

        current_time = clock()

        # Check if the clock has been changed.
        if current_time < info.start_time:
            # Raise this when we get back to Python.
            stash_exception((RuntimeError, RuntimeError("Clock has been changed to before timeout start"), None))
            return 1

    if current_time > info.start_time + info.timeout:
        return 1

    return 0


cdef int pyav_io_open(lib.AVFormatContext *s,
                      lib.AVIOContext **pb,
                      const char *url,
                      int flags,
                      lib.AVDictionary **options) nogil:
    with gil:
        return pyav_io_open_gil(s, pb, url, flags, options)


cdef int pyav_io_open_gil(lib.AVFormatContext *s,
                          lib.AVIOContext **pb,
                          const char *url,
                          int flags,
                          lib.AVDictionary **options):
    cdef Container container
    cdef object file
    cdef PyIOFile pyio_file
    try:
        container = <Container>dereference(s).opaque

        if options is not NULL:
            options_dict = avdict_to_dict(
                dereference(<lib.AVDictionary**>options),
                encoding=container.metadata_encoding,
                errors=container.metadata_errors
            )
        else:
            options_dict = {}

        file = container.io_open(
            <str>url if url is not NULL else "",
            flags,
            options_dict
        )

        pyio_file = PyIOFile(
            file,
            container.buffer_size,
            (flags & lib.AVIO_FLAG_WRITE) != 0
        )

        # Add it to the container to avoid it being deallocated
        container.open_files[<int64_t>pyio_file.iocontext.opaque] = pyio_file

        pb[0] = pyio_file.iocontext
        return 0

    except Exception as e:
        return stash_exception()


cdef void pyav_io_close(lib.AVFormatContext *s,
                        lib.AVIOContext *pb) nogil:
    with gil:
        pyav_io_close_gil(s, pb)


cdef void pyav_io_close_gil(lib.AVFormatContext *s,
                            lib.AVIOContext *pb):
    cdef Container container
    try:
        container = <Container>dereference(s).opaque

        if container.open_files is not None and <int64_t>pb.opaque in container.open_files:
            pyio_close_custom_gil(pb)

            # Remove it from the container so that it can be deallocated
            del container.open_files[<int64_t>pb.opaque]
        else:
            pyio_close_gil(pb)

    except Exception as e:
        stash_exception()


Flags = define_enum('Flags', __name__, (
    ('GENPTS', lib.AVFMT_FLAG_GENPTS,
        "Generate missing pts even if it requires parsing future frames."),
    ('IGNIDX', lib.AVFMT_FLAG_IGNIDX,
        "Ignore index."),
    ('NONBLOCK', lib.AVFMT_FLAG_NONBLOCK,
        "Do not block when reading packets from input."),
    ('IGNDTS', lib.AVFMT_FLAG_IGNDTS,
        "Ignore DTS on frames that contain both DTS & PTS."),
    ('NOFILLIN', lib.AVFMT_FLAG_NOFILLIN,
        "Do not infer any values from other values, just return what is stored in the container."),
    ('NOPARSE', lib.AVFMT_FLAG_NOPARSE,
        """Do not use AVParsers, you also must set AVFMT_FLAG_NOFILLIN as the fillin code works on frames and no parsing -> no frames.

        Also seeking to frames can not work if parsing to find frame boundaries has been disabled."""),
    ('NOBUFFER', lib.AVFMT_FLAG_NOBUFFER,
        "Do not buffer frames when possible."),
    ('CUSTOM_IO', lib.AVFMT_FLAG_CUSTOM_IO,
        "The caller has supplied a custom AVIOContext, don't avio_close() it."),
    ('DISCARD_CORRUPT', lib.AVFMT_FLAG_DISCARD_CORRUPT,
        "Discard frames marked corrupted."),
    ('FLUSH_PACKETS', lib.AVFMT_FLAG_FLUSH_PACKETS,
        "Flush the AVIOContext every packet."),
    ('BITEXACT', lib.AVFMT_FLAG_BITEXACT,
        """When muxing, try to avoid writing any random/volatile data to the output.

        This includes any random IDs, real-time timestamps/dates, muxer version, etc.
        This flag is mainly intended for testing."""),
    ('SORT_DTS', lib.AVFMT_FLAG_SORT_DTS,
        "Try to interleave outputted packets by dts (using this flag can slow demuxing down)."),
    ('PRIV_OPT', lib.AVFMT_FLAG_PRIV_OPT,
        "Enable use of private options by delaying codec open (this could be made default once all code is converted)."),
    ('FAST_SEEK', lib.AVFMT_FLAG_FAST_SEEK,
        "Enable fast, but inaccurate seeks for some formats."),
    ('SHORTEST', lib.AVFMT_FLAG_SHORTEST,
        "Stop muxing when the shortest stream stops."),
    ('AUTO_BSF', lib.AVFMT_FLAG_AUTO_BSF,
        "Add bitstream filters as requested by the muxer."),
), is_flags=True)


AudioCodecs = define_enum('AudioCodecs', __name__, (
    ('NONE', lib.AV_CODEC_ID_NONE),
    ('8SVX_EXP', lib.AV_CODEC_ID_8SVX_EXP),
    ('8SVX_FIB', lib.AV_CODEC_ID_8SVX_FIB),
    ('AAC', lib.AV_CODEC_ID_AAC),
    ('AAC_LATM', lib.AV_CODEC_ID_AAC_LATM),
    ('AC3', lib.AV_CODEC_ID_AC3),
    ('ADPCM_4XM', lib.AV_CODEC_ID_ADPCM_4XM),
    ('ADPCM_ADX', lib.AV_CODEC_ID_ADPCM_ADX),
    ('ADPCM_AFC', lib.AV_CODEC_ID_ADPCM_AFC),
    ('ADPCM_AGM', lib.AV_CODEC_ID_ADPCM_AGM),
    ('ADPCM_AICA', lib.AV_CODEC_ID_ADPCM_AICA),
    ('ADPCM_ARGO', lib.AV_CODEC_ID_ADPCM_ARGO),
    ('ADPCM_CT', lib.AV_CODEC_ID_ADPCM_CT),
    ('ADPCM_DTK', lib.AV_CODEC_ID_ADPCM_DTK),
    ('ADPCM_EA', lib.AV_CODEC_ID_ADPCM_EA),
    ('ADPCM_EA_MAXIS_XA', lib.AV_CODEC_ID_ADPCM_EA_MAXIS_XA),
    ('ADPCM_EA_R1', lib.AV_CODEC_ID_ADPCM_EA_R1),
    ('ADPCM_EA_R2', lib.AV_CODEC_ID_ADPCM_EA_R2),
    ('ADPCM_EA_R3', lib.AV_CODEC_ID_ADPCM_EA_R3),
    ('ADPCM_EA_XAS', lib.AV_CODEC_ID_ADPCM_EA_XAS),
    ('ADPCM_G722', lib.AV_CODEC_ID_ADPCM_G722),
    ('ADPCM_G726', lib.AV_CODEC_ID_ADPCM_G726),
    ('ADPCM_G726LE', lib.AV_CODEC_ID_ADPCM_G726LE),
    ('ADPCM_IMA_ALP', lib.AV_CODEC_ID_ADPCM_IMA_ALP),
    ('ADPCM_IMA_AMV', lib.AV_CODEC_ID_ADPCM_IMA_AMV),
    ('ADPCM_IMA_APC', lib.AV_CODEC_ID_ADPCM_IMA_APC),
    ('ADPCM_IMA_APM', lib.AV_CODEC_ID_ADPCM_IMA_APM),
    ('ADPCM_IMA_CUNNING', lib.AV_CODEC_ID_ADPCM_IMA_CUNNING),
    ('ADPCM_IMA_DAT4', lib.AV_CODEC_ID_ADPCM_IMA_DAT4),
    ('ADPCM_IMA_DK3', lib.AV_CODEC_ID_ADPCM_IMA_DK3),
    ('ADPCM_IMA_DK4', lib.AV_CODEC_ID_ADPCM_IMA_DK4),
    ('ADPCM_IMA_EA_EACS', lib.AV_CODEC_ID_ADPCM_IMA_EA_EACS),
    ('ADPCM_IMA_EA_SEAD', lib.AV_CODEC_ID_ADPCM_IMA_EA_SEAD),
    ('ADPCM_IMA_ISS', lib.AV_CODEC_ID_ADPCM_IMA_ISS),
    ('ADPCM_IMA_MTF', lib.AV_CODEC_ID_ADPCM_IMA_MTF),
    ('ADPCM_IMA_OKI', lib.AV_CODEC_ID_ADPCM_IMA_OKI),
    ('ADPCM_IMA_QT', lib.AV_CODEC_ID_ADPCM_IMA_QT),
    ('ADPCM_IMA_RAD', lib.AV_CODEC_ID_ADPCM_IMA_RAD),
    ('ADPCM_IMA_SMJPEG', lib.AV_CODEC_ID_ADPCM_IMA_SMJPEG),
    ('ADPCM_IMA_SSI', lib.AV_CODEC_ID_ADPCM_IMA_SSI),
    ('ADPCM_IMA_WAV', lib.AV_CODEC_ID_ADPCM_IMA_WAV),
    ('ADPCM_IMA_WS', lib.AV_CODEC_ID_ADPCM_IMA_WS),
    ('ADPCM_MS', lib.AV_CODEC_ID_ADPCM_MS),
    ('ADPCM_MTAF', lib.AV_CODEC_ID_ADPCM_MTAF),
    ('ADPCM_PSX', lib.AV_CODEC_ID_ADPCM_PSX),
    ('ADPCM_SBPRO_2', lib.AV_CODEC_ID_ADPCM_SBPRO_2),
    ('ADPCM_SBPRO_3', lib.AV_CODEC_ID_ADPCM_SBPRO_3),
    ('ADPCM_SBPRO_4', lib.AV_CODEC_ID_ADPCM_SBPRO_4),
    ('ADPCM_SWF', lib.AV_CODEC_ID_ADPCM_SWF),
    ('ADPCM_THP', lib.AV_CODEC_ID_ADPCM_THP),
    ('ADPCM_THP_LE', lib.AV_CODEC_ID_ADPCM_THP_LE),
    ('ADPCM_VIMA', lib.AV_CODEC_ID_ADPCM_VIMA),
    ('ADPCM_XA', lib.AV_CODEC_ID_ADPCM_XA),
    ('ADPCM_YAMAHA', lib.AV_CODEC_ID_ADPCM_YAMAHA),
    ('ADPCM_ZORK', lib.AV_CODEC_ID_ADPCM_ZORK),
    ('ALAC', lib.AV_CODEC_ID_ALAC),
    ('AMR_NB', lib.AV_CODEC_ID_AMR_NB),
    ('AMR_WB', lib.AV_CODEC_ID_AMR_WB),
    ('APE', lib.AV_CODEC_ID_APE),
    ('APTX', lib.AV_CODEC_ID_APTX),
    ('APTX_HD', lib.AV_CODEC_ID_APTX_HD),
    ('ATRAC1', lib.AV_CODEC_ID_ATRAC1),
    ('ATRAC3', lib.AV_CODEC_ID_ATRAC3),
    ('ATRAC3AL', lib.AV_CODEC_ID_ATRAC3AL),
    ('ATRAC3P', lib.AV_CODEC_ID_ATRAC3P),
    ('ATRAC3PAL', lib.AV_CODEC_ID_ATRAC3PAL),
    ('ATRAC9', lib.AV_CODEC_ID_ATRAC9),
    ('BINKAUDIO_DCT', lib.AV_CODEC_ID_BINKAUDIO_DCT),
    ('BINKAUDIO_RDFT', lib.AV_CODEC_ID_BINKAUDIO_RDFT),
    ('BMV_AUDIO', lib.AV_CODEC_ID_BMV_AUDIO),
    ('COMFORT_NOISE', lib.AV_CODEC_ID_COMFORT_NOISE),
    ('COOK', lib.AV_CODEC_ID_COOK),
    ('DERF_DPCM', lib.AV_CODEC_ID_DERF_DPCM),
    ('DOLBY_E', lib.AV_CODEC_ID_DOLBY_E),
    ('DSD_LSBF', lib.AV_CODEC_ID_DSD_LSBF),
    ('DSD_LSBF_PLANAR', lib.AV_CODEC_ID_DSD_LSBF_PLANAR),
    ('DSD_MSBF', lib.AV_CODEC_ID_DSD_MSBF),
    ('DSD_MSBF_PLANAR', lib.AV_CODEC_ID_DSD_MSBF_PLANAR),
    ('DSICINAUDIO', lib.AV_CODEC_ID_DSICINAUDIO),
    ('DSS_SP', lib.AV_CODEC_ID_DSS_SP),
    ('DST', lib.AV_CODEC_ID_DST),
    ('DTS', lib.AV_CODEC_ID_DTS),
    ('DVAUDIO', lib.AV_CODEC_ID_DVAUDIO),
    ('EAC3', lib.AV_CODEC_ID_EAC3),
    ('EVRC', lib.AV_CODEC_ID_EVRC),
    ('FFWAVESYNTH', lib.AV_CODEC_ID_FFWAVESYNTH),
    ('FLAC', lib.AV_CODEC_ID_FLAC),
    ('G723_1', lib.AV_CODEC_ID_G723_1),
    ('G729', lib.AV_CODEC_ID_G729),
    ('GREMLIN_DPCM', lib.AV_CODEC_ID_GREMLIN_DPCM),
    ('GSM', lib.AV_CODEC_ID_GSM),
    ('GSM_MS', lib.AV_CODEC_ID_GSM_MS),
    ('HCA', lib.AV_CODEC_ID_HCA),
    ('HCOM', lib.AV_CODEC_ID_HCOM),
    ('IAC', lib.AV_CODEC_ID_IAC),
    ('ILBC', lib.AV_CODEC_ID_ILBC),
    ('IMC', lib.AV_CODEC_ID_IMC),
    ('INTERPLAY_ACM', lib.AV_CODEC_ID_INTERPLAY_ACM),
    ('INTERPLAY_DPCM', lib.AV_CODEC_ID_INTERPLAY_DPCM),
    ('MACE3', lib.AV_CODEC_ID_MACE3),
    ('MACE6', lib.AV_CODEC_ID_MACE6),
    ('METASOUND', lib.AV_CODEC_ID_METASOUND),
    ('MLP', lib.AV_CODEC_ID_MLP),
    ('MP1', lib.AV_CODEC_ID_MP1),
    ('MP2', lib.AV_CODEC_ID_MP2),
    ('MP3', lib.AV_CODEC_ID_MP3),
    ('MP3ADU', lib.AV_CODEC_ID_MP3ADU),
    ('MP3ON4', lib.AV_CODEC_ID_MP3ON4),
    ('MP4ALS', lib.AV_CODEC_ID_MP4ALS),
    ('MUSEPACK7', lib.AV_CODEC_ID_MUSEPACK7),
    ('MUSEPACK8', lib.AV_CODEC_ID_MUSEPACK8),
    ('NELLYMOSER', lib.AV_CODEC_ID_NELLYMOSER),
    ('ON2AVC', lib.AV_CODEC_ID_ON2AVC),
    ('OPUS', lib.AV_CODEC_ID_OPUS),
    ('PAF_AUDIO', lib.AV_CODEC_ID_PAF_AUDIO),
    ('PCM_ALAW', lib.AV_CODEC_ID_PCM_ALAW),
    ('PCM_BLURAY', lib.AV_CODEC_ID_PCM_BLURAY),
    ('PCM_DVD', lib.AV_CODEC_ID_PCM_DVD),
    ('PCM_F16LE', lib.AV_CODEC_ID_PCM_F16LE),
    ('PCM_F24LE', lib.AV_CODEC_ID_PCM_F24LE),
    ('PCM_F32BE', lib.AV_CODEC_ID_PCM_F32BE),
    ('PCM_F32LE', lib.AV_CODEC_ID_PCM_F32LE),
    ('PCM_F64BE', lib.AV_CODEC_ID_PCM_F64BE),
    ('PCM_F64LE', lib.AV_CODEC_ID_PCM_F64LE),
    ('PCM_LXF', lib.AV_CODEC_ID_PCM_LXF),
    ('PCM_MULAW', lib.AV_CODEC_ID_PCM_MULAW),
    ('PCM_S16BE', lib.AV_CODEC_ID_PCM_S16BE),
    ('PCM_S16BE_PLANAR', lib.AV_CODEC_ID_PCM_S16BE_PLANAR),
    ('PCM_S16LE', lib.AV_CODEC_ID_PCM_S16LE),
    ('PCM_S16LE_PLANAR', lib.AV_CODEC_ID_PCM_S16LE_PLANAR),
    ('PCM_S24BE', lib.AV_CODEC_ID_PCM_S24BE),
    ('PCM_S24DAUD', lib.AV_CODEC_ID_PCM_S24DAUD),
    ('PCM_S24LE', lib.AV_CODEC_ID_PCM_S24LE),
    ('PCM_S24LE_PLANAR', lib.AV_CODEC_ID_PCM_S24LE_PLANAR),
    ('PCM_S32BE', lib.AV_CODEC_ID_PCM_S32BE),
    ('PCM_S32LE', lib.AV_CODEC_ID_PCM_S32LE),
    ('PCM_S32LE_PLANAR', lib.AV_CODEC_ID_PCM_S32LE_PLANAR),
    ('PCM_S64BE', lib.AV_CODEC_ID_PCM_S64BE),
    ('PCM_S64LE', lib.AV_CODEC_ID_PCM_S64LE),
    ('PCM_S8', lib.AV_CODEC_ID_PCM_S8),
    ('PCM_S8_PLANAR', lib.AV_CODEC_ID_PCM_S8_PLANAR),
    ('PCM_U16BE', lib.AV_CODEC_ID_PCM_U16BE),
    ('PCM_U16LE', lib.AV_CODEC_ID_PCM_U16LE),
    ('PCM_U24BE', lib.AV_CODEC_ID_PCM_U24BE),
    ('PCM_U24LE', lib.AV_CODEC_ID_PCM_U24LE),
    ('PCM_U32BE', lib.AV_CODEC_ID_PCM_U32BE),
    ('PCM_U32LE', lib.AV_CODEC_ID_PCM_U32LE),
    ('PCM_U8', lib.AV_CODEC_ID_PCM_U8),
    ('PCM_VIDC', lib.AV_CODEC_ID_PCM_VIDC),
    ('QCELP', lib.AV_CODEC_ID_QCELP),
    ('QCELP', lib.AV_CODEC_ID_QCELP),
    ('QDM2', lib.AV_CODEC_ID_QDM2),
    ('QDMC', lib.AV_CODEC_ID_QDMC),
    ('RALF', lib.AV_CODEC_ID_RALF),
    ('RA_144', lib.AV_CODEC_ID_RA_144),
    ('RA_288', lib.AV_CODEC_ID_RA_288),
    ('ROQ_DPCM', lib.AV_CODEC_ID_ROQ_DPCM),
    ('S302M', lib.AV_CODEC_ID_S302M),
    ('SBC', lib.AV_CODEC_ID_SBC),
    ('SDX2_DPCM', lib.AV_CODEC_ID_SDX2_DPCM),
    ('SHORTEN', lib.AV_CODEC_ID_SHORTEN),
    ('SIPR', lib.AV_CODEC_ID_SIPR),
    ('SIREN', lib.AV_CODEC_ID_SIREN),
    ('SMACKAUDIO', lib.AV_CODEC_ID_SMACKAUDIO),
    ('SOL_DPCM', lib.AV_CODEC_ID_SOL_DPCM),
    ('SONIC', lib.AV_CODEC_ID_SONIC),
    ('SPEEX', lib.AV_CODEC_ID_SPEEX),
    ('TAK', lib.AV_CODEC_ID_TAK),
    ('TRUEHD', lib.AV_CODEC_ID_TRUEHD),
    ('TRUESPEECH', lib.AV_CODEC_ID_TRUESPEECH),
    ('TTA', lib.AV_CODEC_ID_TTA),
    ('TWINVQ', lib.AV_CODEC_ID_TWINVQ),
    ('VMDAUDIO', lib.AV_CODEC_ID_VMDAUDIO),
    ('VORBIS', lib.AV_CODEC_ID_VORBIS),
    ('WAVPACK', lib.AV_CODEC_ID_WAVPACK),
    ('WESTWOOD_SND1', lib.AV_CODEC_ID_WESTWOOD_SND1),
    ('WMALOSSLESS', lib.AV_CODEC_ID_WMALOSSLESS),
    ('WMAPRO', lib.AV_CODEC_ID_WMAPRO),
    ('WMAV1', lib.AV_CODEC_ID_WMAV1),
    ('WMAV2', lib.AV_CODEC_ID_WMAV2),
    ('WMAVOICE', lib.AV_CODEC_ID_WMAVOICE),
    ('XAN_DPCM', lib.AV_CODEC_ID_XAN_DPCM),
    ('XMA1', lib.AV_CODEC_ID_XMA1),
    ('XMA2', lib.AV_CODEC_ID_XMA2)
))


cdef class Container(object):

    def __cinit__(self, sentinel, file_, format_name, options,
                  container_options, stream_options,
                  metadata_encoding, metadata_errors,
                  buffer_size, open_timeout, read_timeout,
                  io_open, audio_codec=AudioCodecs['NONE']):

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct base Container')

        self.writeable = isinstance(self, OutputContainer)
        if not self.writeable and not isinstance(self, InputContainer):
            raise RuntimeError('Container cannot be directly extended.')

        if isinstance(file_, str):
            self.name = file_
        else:
            self.name = str(getattr(file_, 'name', '<none>'))

        self.options = dict(options or ())
        self.container_options = dict(container_options or ())
        self.stream_options = [dict(x) for x in stream_options or ()]

        self.metadata_encoding = metadata_encoding
        self.metadata_errors = metadata_errors

        self.open_timeout = open_timeout
        self.read_timeout = read_timeout

        self.buffer_size = buffer_size
        self.io_open = io_open

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.input_was_opened = False
        cdef int res

        cdef bytes name_obj = os.fsencode(self.name)
        cdef char *name = name_obj
        cdef seek_func_t seek_func = NULL

        cdef lib.AVOutputFormat *ofmt
        if self.writeable:

            ofmt = self.format.optr if self.format else lib.av_guess_format(NULL, name, NULL)
            if ofmt == NULL:
                raise ValueError("Could not determine output format")

            with nogil:
                # This does not actually open the file.
                res = lib.avformat_alloc_output_context2(
                    &self.ptr,
                    ofmt,
                    NULL,
                    name,
                )
            self.err_check(res)

        else:
            # We need the context before we open the input AND setup Python IO.
            self.ptr = lib.avformat_alloc_context()

            # Setup interrupt callback
            if self.open_timeout is not None or self.read_timeout is not None:
                self.ptr.interrupt_callback.callback = interrupt_cb
                self.ptr.interrupt_callback.opaque = &self.interrupt_callback_info

        self.ptr.flags |= lib.AVFMT_FLAG_GENPTS
        self.ptr.opaque = <void*>self

        self.ptr.audio_codec_id = audio_codec

        # Setup Python IO.
        self.open_files = {}
        if not isinstance(file_, basestring):
            self.file = PyIOFile(file_, buffer_size, self.writeable)
            self.ptr.pb = self.file.iocontext

        if io_open is not None:
            self.ptr.io_open = pyav_io_open
            self.ptr.io_close = pyav_io_close
            self.ptr.flags |= lib.AVFMT_FLAG_CUSTOM_IO

        cdef lib.AVInputFormat *ifmt
        cdef _Dictionary c_options
        if not self.writeable:

            ifmt = self.format.iptr if self.format else NULL

            c_options = Dictionary(self.options, self.container_options)

            self.set_timeout(self.open_timeout)
            self.start_timeout()
            with nogil:
                res = lib.avformat_open_input(
                    &self.ptr,
                    name,
                    ifmt,
                    &c_options.ptr
                )
            self.set_timeout(None)
            self.err_check(res)
            self.input_was_opened = True

        if format_name is None:
            self.format = build_container_format(self.ptr.iformat, self.ptr.oformat)

    def __dealloc__(self):
        with nogil:
            lib.avformat_free_context(self.ptr)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.file or self.name)

    cdef int err_check(self, int value) except -1:
        return err_check(value, filename=self.name)

    def dumps_format(self):
        with LogCapture() as logs:
            lib.av_dump_format(self.ptr, 0, "", isinstance(self, OutputContainer))
        return ''.join(log[2] for log in logs)

    cdef set_timeout(self, timeout):
        if timeout is None:
            self.interrupt_callback_info.timeout = -1.0
        else:
            self.interrupt_callback_info.timeout = timeout

    cdef start_timeout(self):
        self.interrupt_callback_info.start_time = clock()

    def _get_flags(self):
        return self.ptr.flags

    def _set_flags(self, value):
        self.ptr.flags = value

    flags = Flags.property(
        _get_flags,
        _set_flags,
        """Flags property of :class:`.Flags`"""
    )

    gen_pts = flags.flag_property('GENPTS')
    ign_idx = flags.flag_property('IGNIDX')
    non_block = flags.flag_property('NONBLOCK')
    ign_dts = flags.flag_property('IGNDTS')
    no_fill_in = flags.flag_property('NOFILLIN')
    no_parse = flags.flag_property('NOPARSE')
    no_buffer = flags.flag_property('NOBUFFER')
    custom_io = flags.flag_property('CUSTOM_IO')
    discard_corrupt = flags.flag_property('DISCARD_CORRUPT')
    flush_packets = flags.flag_property('FLUSH_PACKETS')
    bit_exact = flags.flag_property('BITEXACT')
    sort_dts = flags.flag_property('SORT_DTS')
    priv_opt = flags.flag_property('PRIV_OPT')
    fast_seek = flags.flag_property('FAST_SEEK')
    shortest = flags.flag_property('SHORTEST')
    auto_bsf = flags.flag_property('AUTO_BSF')


def open(file, mode=None, format=None, options=None,
         container_options=None, stream_options=None,
         metadata_encoding='utf-8', metadata_errors='strict',
         buffer_size=32768, timeout=None, io_open=None):
    """open(file, mode='r', **kwargs)

    Main entrypoint to opening files/streams.

    :param str file: The file to open, which can be either a string or a file-like object.
    :param str mode: ``"r"`` for reading and ``"w"`` for writing.
    :param str format: Specific format to use. Defaults to autodect.
    :param dict options: Options to pass to the container and all streams.
    :param dict container_options: Options to pass to the container.
    :param list stream_options: Options to pass to each stream.
    :param str metadata_encoding: Encoding to use when reading or writing file metadata.
        Defaults to ``"utf-8"``.
    :param str metadata_errors: Specifies how to handle encoding errors; behaves like
        ``str.encode`` parameter. Defaults to ``"strict"``.
    :param int buffer_size: Size of buffer for Python input/output operations in bytes.
        Honored only when ``file`` is a file-like object. Defaults to 32768 (32k).
    :param timeout: How many seconds to wait for data before giving up, as a float, or a
        :ref:`(open timeout, read timeout) <timeouts>` tuple.
    :type timeout: float or tuple
    :param callable io_open: Custom I/O callable for opening files/streams.
        This option is intended for formats that need to open additional
        file-like objects to ``file`` using custom I/O.
        The callable signature is ``io_open(url: str, flags: int, options: dict)``, where
        ``url`` is the url to open, ``flags`` is a combination of AVIO_FLAG_* and
        ``options`` is a dictionary of additional options. The callable should return a
        file-like object.

    For devices (via ``libavdevice``), pass the name of the device to ``format``,
    e.g.::

        >>> # Open webcam on OS X.
        >>> av.open(format='avfoundation', file='0') # doctest: +SKIP

    For DASH and custom I/O using ``io_open``, add a protocol prefix to the ``file`` to
    prevent the DASH encoder defaulting to the file protocol and using temporary files.
    The custom I/O callable can be used to remove the protocol prefix to reveal the actual
    name for creating the file-like object. E.g.::

        >>> av.open("customprotocol://manifest.mpd", "w", io_open=custom_io) # doctest: +SKIP

    .. seealso:: :ref:`garbage_collection`

    More information on using input and output devices is available on the
    `FFmpeg website <https://www.ffmpeg.org/ffmpeg-devices.html>`_.
    """

    if mode is None:
        mode = getattr(file, 'mode', None)
    if mode is None:
        mode = 'r'

    if isinstance(timeout, tuple):
        open_timeout = timeout[0]
        read_timeout = timeout[1]
    else:
        open_timeout = timeout
        read_timeout = timeout

    if mode.startswith('r'):
        return InputContainer(
            _cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors,
            buffer_size, open_timeout, read_timeout,
            io_open
        )
    if mode.startswith('w'):
        if stream_options:
            raise ValueError("Provide stream options via Container.add_stream(..., options={}).")
        return OutputContainer(
            _cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors,
            buffer_size, open_timeout, read_timeout,
            io_open
        )
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)
