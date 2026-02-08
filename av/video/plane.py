import cython
import cython.cimports.libav as lib
from cython.cimports.av.error import err_check
from cython.cimports.av.video.format import get_pix_fmt, get_video_format
from cython.cimports.av.video.frame import VideoFrame
from cython.cimports.cpython import PyBUF_WRITABLE, PyBuffer_FillInfo
from cython.cimports.cpython.buffer import Py_buffer
from cython.cimports.cpython.pycapsule import (
    PyCapsule_GetPointer,
    PyCapsule_IsValid,
    PyCapsule_New,
)
from cython.cimports.libc.stdlib import free, malloc


@cython.cclass
class VideoPlane(Plane):
    def __cinit__(self, frame: VideoFrame, index: cython.int):
        # The palette plane has no associated component or linesize; set fields manually
        fmt = frame.format
        if frame.ptr.hw_frames_ctx:
            frames_ctx: cython.pointer[lib.AVHWFramesContext] = cython.cast(
                cython.pointer[lib.AVHWFramesContext], frame.ptr.hw_frames_ctx.data
            )
            fmt = get_video_format(
                frames_ctx.sw_format, frame.ptr.width, frame.ptr.height
            )

        if fmt.name == "pal8" and index == 1:
            self.width = 256
            self.height = 1
            self.buffer_size = 256 * 4
            return

        for i in range(fmt.ptr.nb_components):
            if fmt.ptr.comp[i].plane == index:
                component = fmt.components[i]
                self.width = component.width
                self.height = component.height
                break
        else:
            raise RuntimeError(f"could not find plane {index} of {fmt!r}")

        # Sometimes, linesize is negative (and that is meaningful). We are only
        # insisting that the buffer size be based on the extent of linesize, and
        # ignore it's direction.
        self.buffer_size = abs(self.frame.ptr.linesize[self.index]) * self.height

    @cython.cfunc
    def _buffer_size(self) -> cython.size_t:
        return self.buffer_size

    @property
    def line_size(self):
        """
        Bytes per horizontal line in this plane.

        :type: int
        """
        return self.frame.ptr.linesize[self.index]

    @cython.cfunc
    def _buffer_writable(self) -> cython.bint:
        if self.frame.ptr.hw_frames_ctx:
            return False
        return True

    def __getbuffer__(self, view: cython.pointer[Py_buffer], flags: cython.int):
        if self.frame.ptr.hw_frames_ctx:
            raise TypeError(
                "Hardware frame planes do not support the Python buffer protocol. "
                "Use DLPack (__dlpack__) or download to a software frame."
            )
        if flags & PyBUF_WRITABLE and not self._buffer_writable():
            raise ValueError("buffer is not writable")
        PyBuffer_FillInfo(view, self, self._buffer_ptr(), self._buffer_size(), 0, flags)

    def __dlpack_device__(self):
        if self.frame.ptr.hw_frames_ctx:
            if cython.cast(lib.AVPixelFormat, self.frame.ptr.format) != get_pix_fmt(
                b"cuda"
            ):
                raise NotImplementedError(
                    "DLPack export is only implemented for CUDA hw frames"
                )
            return (kCuda, self.frame.device_id)
        return (kCPU, 0)

    def __dlpack__(self, stream: int | None = None):
        if self.frame.ptr.buf[0] == cython.NULL:
            raise TypeError(
                "DLPack export requires a refcounted AVFrame (frame.buf[0] is NULL)"
            )

        sw_fmt: lib.AVPixelFormat
        device_type: cython.int
        device_id: cython.int

        if self.frame.ptr.hw_frames_ctx:
            if cython.cast(lib.AVPixelFormat, self.frame.ptr.format) != get_pix_fmt(
                b"cuda"
            ):
                raise NotImplementedError(
                    "DLPack export is only implemented for CUDA hw frames"
                )

            frames_ctx: cython.pointer[lib.AVHWFramesContext] = cython.cast(
                cython.pointer[lib.AVHWFramesContext], self.frame.ptr.hw_frames_ctx.data
            )
            sw_fmt = frames_ctx.sw_format
            device_type = kCuda
            device_id = self.frame.hwaccel_ctx.device_id
        else:
            sw_fmt = cython.cast(lib.AVPixelFormat, self.frame.ptr.format)
            device_type = kCPU
            device_id = 0

        line_size = self.line_size
        if line_size < 0:
            raise NotImplementedError(
                "negative linesize is not supported for DLPack export"
            )

        nv12 = get_pix_fmt(b"nv12")
        p010le = get_pix_fmt(b"p010le")
        p016le = get_pix_fmt(b"p016le")

        ndim, bits, itemsize = cython.declare(cython.int)
        s0, s1, s2 = cython.declare(int64_t)
        st0, st1, st2 = cython.declare(int64_t)

        if sw_fmt == nv12:
            itemsize = 1
            bits = 8
            if self.index == 0:
                ndim = 2
                s0 = self.frame.ptr.height
                s1 = self.frame.ptr.width
                st0 = line_size
                st1 = 1
            elif self.index == 1:
                ndim = 3
                s0 = self.frame.ptr.height // 2
                s1 = self.frame.ptr.width // 2
                s2 = 2
                st0 = line_size
                st1 = 2
                st2 = 1
            else:
                raise ValueError("invalid plane index for NV12")
        elif sw_fmt == p010le or sw_fmt == p016le:
            itemsize = 2
            bits = 16
            if line_size % itemsize:
                raise ValueError("linesize is not aligned to dtype")
            if self.index == 0:
                ndim = 2
                s0 = self.frame.ptr.height
                s1 = self.frame.ptr.width
                st0 = line_size // itemsize
                st1 = 1
            elif self.index == 1:
                ndim = 3
                s0 = self.frame.ptr.height // 2
                s1 = self.frame.ptr.width // 2
                s2 = 2
                st0 = line_size // itemsize
                st1 = 2
                st2 = 1
            else:
                raise ValueError("invalid plane index for P010/P016")
        else:
            raise NotImplementedError("unsupported sw_format for DLPack export")

        frame_ref: cython.pointer[lib.AVFrame] = lib.av_frame_alloc()
        if frame_ref == cython.NULL:
            raise MemoryError("av_frame_alloc() failed")
        err_check(lib.av_frame_ref(frame_ref, self.frame.ptr))

        shape = cython.cast(
            cython.pointer[int64_t], malloc(ndim * cython.sizeof(int64_t))
        )
        strides = cython.cast(
            cython.pointer[int64_t], malloc(ndim * cython.sizeof(int64_t))
        )
        if shape == cython.NULL or strides == cython.NULL:
            if shape != cython.NULL:
                free(shape)
            if strides != cython.NULL:
                free(strides)
            lib.av_frame_free(cython.address(frame_ref))
            raise MemoryError("malloc() failed")

        if ndim == 2:
            shape[0] = s0
            shape[1] = s1
            strides[0] = st0
            strides[1] = st1
        else:
            shape[0] = s0
            shape[1] = s1
            shape[2] = s2
            strides[0] = st0
            strides[1] = st1
            strides[2] = st2

        ctx = cython.cast(
            cython.pointer[cython.p_void], malloc(3 * cython.sizeof(cython.p_void))
        )
        if ctx == cython.NULL:
            free(shape)
            free(strides)
            lib.av_frame_free(cython.address(frame_ref))
            raise MemoryError("malloc() failed")

        ctx[0] = cython.cast(cython.p_void, frame_ref)
        ctx[1] = cython.cast(cython.p_void, shape)
        ctx[2] = cython.cast(cython.p_void, strides)

        managed = cython.cast(
            cython.pointer[DLManagedTensor], malloc(cython.sizeof(DLManagedTensor))
        )
        if managed == cython.NULL:
            free(ctx)
            free(shape)
            free(strides)
            lib.av_frame_free(cython.address(frame_ref))
            raise MemoryError("malloc() failed")

        managed.dl_tensor.data = cython.cast(cython.p_void, frame_ref.data[self.index])
        managed.dl_tensor.device_type = device_type
        managed.dl_tensor.device_id = device_id
        managed.dl_tensor.ndim = ndim
        managed.dl_tensor.dtype = DLDataType(code=1, bits=bits, lanes=1)
        managed.dl_tensor.shape = shape
        managed.dl_tensor.strides = strides
        managed.dl_tensor.byte_offset = 0
        managed.manager_ctx = cython.cast(cython.p_void, ctx)
        managed.deleter = _dlpack_managed_tensor_deleter

        try:
            capsule = PyCapsule_New(
                cython.cast(cython.p_void, managed),
                b"dltensor",
                _dlpack_capsule_destructor,
            )
        except Exception:
            _dlpack_managed_tensor_deleter(managed)
            raise

        return capsule


@cython.cfunc
@cython.nogil
@cython.exceptval(check=False)
def _dlpack_managed_tensor_deleter(
    managed: cython.pointer[DLManagedTensor],
) -> cython.void:
    if managed == cython.NULL:
        return
    ctx = cython.cast(cython.pointer[cython.p_void], managed.manager_ctx)
    if ctx != cython.NULL:
        frame_ref = cython.cast(cython.pointer[lib.AVFrame], ctx[0])
        shape = cython.cast(cython.pointer[int64_t], ctx[1])
        strides = cython.cast(cython.pointer[int64_t], ctx[2])

        if frame_ref != cython.NULL:
            lib.av_frame_free(cython.address(frame_ref))
        if shape != cython.NULL:
            free(shape)
        if strides != cython.NULL:
            free(strides)
        free(ctx)

    free(managed)


@cython.cfunc
@cython.exceptval(check=False)
def _dlpack_capsule_destructor(capsule: object) -> cython.void:
    if PyCapsule_IsValid(capsule, b"dltensor"):
        managed = cython.cast(
            cython.pointer[DLManagedTensor],
            PyCapsule_GetPointer(capsule, b"dltensor"),
        )
        if managed != cython.NULL:
            managed.deleter(managed)
