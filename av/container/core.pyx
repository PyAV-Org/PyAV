from libc.stdint cimport int64_t
from libc.stdlib cimport malloc, free

import sys

cimport libav as lib

from av.container.input cimport InputContainer
from av.container.output cimport OutputContainer
from av.container.pyio cimport pyio_read, pyio_write, pyio_seek
from av.format cimport build_container_format
from av.utils cimport err_check, dict_to_avdict

from av.dictionary import Dictionary  # not cimport
from av.logging import Capture as LogCapture  # not cimport
from av.utils import AVError  # not cimport

try:
    from os import fsencode
except ImportError:
    _fsencoding = sys.getfilesystemencoding()

    def fsencode(s):
        return s.encode(_fsencoding)


ctypedef int64_t (*seek_func_t)(void *opaque, int64_t offset, int whence) nogil


cdef object _cinit_sentinel = object()


cdef class Container(object):

    def __cinit__(self, sentinel, file_, format_name, options,
                  container_options, stream_options,
                  metadata_encoding, metadata_errors,
                  buffer_size):

        if sentinel is not _cinit_sentinel:
            raise RuntimeError('cannot construct base Container')

        self.writeable = isinstance(self, OutputContainer)
        if not self.writeable and not isinstance(self, InputContainer):
            raise RuntimeError('Container cannot be directly extended.')

        if isinstance(file_, basestring):
            self.name = file_
        else:
            self.name = getattr(file_, 'name', '<none>')
            if not isinstance(self.name, basestring):
                raise TypeError("File's name attribute must be string-like.")
            self.file = file_

        self.options = dict(options or ())
        self.container_options = dict(container_options or ())
        self.stream_options = [dict(x) for x in stream_options or ()]

        self.metadata_encoding = metadata_encoding
        self.metadata_errors = metadata_errors

        if format_name is not None:
            self.format = ContainerFormat(format_name)

        self.input_was_opened = False
        cdef int res

        cdef bytes name_obj = fsencode(self.name) if isinstance(self.name, unicode) else self.name
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

        self.ptr.flags |= lib.AVFMT_FLAG_GENPTS
        self.ptr.max_analyze_duration = 10000000

        # Setup Python IO.
        if self.file is not None:

            self.fread = getattr(self.file, 'read', None)
            self.fwrite = getattr(self.file, 'write', None)
            self.fseek = getattr(self.file, 'seek', None)
            self.ftell = getattr(self.file, 'tell', None)

            if self.writeable:
                if self.fwrite is None:
                    raise ValueError("File object has no write method.")
            else:
                if self.fread is None:
                    raise ValueError("File object has no read method.")

            if self.fseek is not None and self.ftell is not None:
                seek_func = pyio_seek

            self.pos = 0
            self.pos_is_valid = True

            # This is effectively the maximum size of reads.
            self.buffer = <unsigned char*>lib.av_malloc(buffer_size)

            self.iocontext = lib.avio_alloc_context(
                self.buffer, buffer_size,
                self.writeable,  # Writeable.
                <void*>self,  # User data.
                pyio_read,
                pyio_write,
                seek_func
            )

            if seek_func:
                self.iocontext.seekable = lib.AVIO_SEEKABLE_NORMAL
            self.iocontext.max_packet_size = buffer_size
            self.ptr.pb = self.iocontext

        cdef lib.AVInputFormat *ifmt
        cdef _Dictionary c_options
        if not self.writeable:

            ifmt = self.format.iptr if self.format else NULL

            c_options = Dictionary(self.options, self.container_options)
            with nogil:
                res = lib.avformat_open_input(
                    &self.ptr,
                    name,
                    ifmt,
                    &c_options.ptr
                )
            self.err_check(res)
            self.input_was_opened = True

        if format_name is None:
            self.format = build_container_format(self.ptr.iformat, self.ptr.oformat)

    def __dealloc__(self):
        with nogil:
            # FFmpeg will not release custom input, so it's up to us to free it.
            # Do not touch our original buffer as it may have been freed and replaced.
            if self.iocontext:
                lib.av_freep(&self.iocontext.buffer)
                lib.av_freep(&self.iocontext)

            # We likely errored badly if we got here, and so are still
            # responsible for our buffer.
            else:
                lib.av_freep(&self.buffer)

            # Finish releasing the whole structure.
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


def open(file, mode=None, format=None, options=None,
         container_options=None, stream_options=None,
         metadata_encoding=None, metadata_errors='strict',
         buffer_size=32768):
    """open(file, mode='r', format=None, options=None, metadata_encoding=None, metadata_errors='strict')

    Main entrypoint to opening files/streams.

    :param str file: The file to open, which can be either a string or a file-like object.
    :param str mode: ``"r"`` for reading and ``"w"`` for writing.
    :param str format: Specific format to use. Defaults to autodect.
    :param dict options: Options to pass to the container and all streams.
    :param dict container_options: Options to pass to the container.
    :param list stream_options: Options to pass to each stream.
    :param str metadata_encoding: Encoding to use when reading or writing file metadata.
        Defaults to utf-8, except no decoding is performed by default when
        reading on Python 2 (returning ``str`` instead of ``unicode``).
    :param str metadata_errors: Specifies how to handle encoding errors; behaves like
        ``str.encode`` parameter. Defaults to strict.
    :param int buffer_size: Size of buffer for Python input/output operations in bytes.
        Honored only when ``file`` is a file-like object. Defaults to 32768 (32k).

    For devices (via ``libavdevice``), pass the name of the device to ``format``,
    e.g.::

        >>> # Open webcam on OS X.
        >>> av.open(format='avfoundation', file='0') # doctest: +SKIP

    More information on using input and output devices is available on the
    `FFmpeg website <https://www.ffmpeg.org/ffmpeg-devices.html>`_.
    """

    if mode is None:
        mode = getattr(file, 'mode', None)
    if mode is None:
        mode = 'r'

    if mode.startswith('r'):
        return InputContainer(
            _cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors,
            buffer_size
        )
    if mode.startswith('w'):
        if stream_options:
            raise ValueError("Provide stream options via Container.add_stream(..., options={}).")
        return OutputContainer(
            _cinit_sentinel, file, format, options,
            container_options, stream_options,
            metadata_encoding, metadata_errors,
            buffer_size
        )
    raise ValueError("mode must be 'r' or 'w'; got %r" % mode)
