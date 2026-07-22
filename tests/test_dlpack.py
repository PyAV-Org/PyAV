import gc
from fractions import Fraction

import numpy
import pytest

import av
from av import VideoFrame
from av.codec.hwaccel import HWAccel

from .common import assertNdarraysEqual, fate_png


def _make_u8(shape: tuple[int, ...]) -> numpy.ndarray:
    return numpy.arange(int(numpy.prod(shape)), dtype=numpy.uint8).reshape(shape)


def _make_u16(shape: tuple[int, ...]) -> numpy.ndarray:
    return numpy.arange(int(numpy.prod(shape)), dtype=numpy.uint16).reshape(shape)


def _plane_to_2d(plane, height: int, width: int, dtype) -> numpy.ndarray:
    itemsize = numpy.dtype(dtype).itemsize
    assert plane.line_size % itemsize == 0
    pitch_elems = plane.line_size // itemsize
    arr = numpy.frombuffer(memoryview(plane), dtype=dtype).reshape(height, pitch_elems)
    return arr[:, :width]


def _get_cuda_backend():
    try:
        import cupy  # type: ignore

        try:
            if cupy.cuda.runtime.getDeviceCount() > 0:
                return ("cupy", cupy)
        except Exception:
            pass
    except Exception:
        pass

    try:
        import torch  # type: ignore

        if torch.cuda.is_available():
            return ("torch", torch)
    except Exception:
        pass

    return None


def test_hwaccel_validation_and_primary_ctx() -> None:
    hw = HWAccel(device_type="cuda")
    assert hw.is_hw_owned == False
    assert "primary_ctx" not in hw.options

    hw = HWAccel(device_type="cuda", is_hw_owned=True)
    assert hw.is_hw_owned == True
    assert hw.options.get("primary_ctx") == "1"

    hw = HWAccel(device_type="cuda", is_hw_owned=True, options={"primary_ctx": "0"})
    assert hw.options.get("primary_ctx") == "0"


def test_video_frame_from_dlpack_nv12_cpu_basic_zero_copy_and_lifetime() -> None:
    width, height = 64, 48
    y = _make_u8((height, width))
    uv = _make_u8((height // 2, width // 2, 2))

    frame = VideoFrame.from_dlpack((y, uv), format="nv12")

    assert frame.format.name == "nv12"
    assert frame.width == width
    assert frame.height == height
    assert len(frame.planes) == 2
    assert frame.planes[0].width == width
    assert frame.planes[0].height == height
    assert frame.planes[1].width == width // 2
    assert frame.planes[1].height == height // 2
    assert frame.planes[0].line_size == width
    assert frame.planes[1].line_size == width

    y_plane = _plane_to_2d(frame.planes[0], height, width, numpy.uint8)
    uv_plane = _plane_to_2d(frame.planes[1], height // 2, width, numpy.uint8)
    assertNdarraysEqual(y_plane, y)
    assertNdarraysEqual(uv_plane, uv.reshape(height // 2, width))

    y[0, 0] = 123
    uv[0, 0, 0] = 11
    uv[0, 0, 1] = 22

    expected_y_bytes = y.tobytes()
    expected_uv_bytes = uv.reshape(height // 2, width).tobytes()

    assert memoryview(frame.planes[0])[0] == 123
    assert memoryview(frame.planes[1])[0] == 11
    assert memoryview(frame.planes[1])[1] == 22

    del y
    del uv
    gc.collect()

    assert bytes(frame.planes[0]) == expected_y_bytes
    assert bytes(frame.planes[1]) == expected_uv_bytes


def test_video_frame_from_dlpack_nv12_cpu_with_pitch_and_dlpack_export() -> None:
    width, height = 64, 48
    pad = 16

    y_base = _make_u8((height, width + pad))
    y = y_base[:, :width]
    uv_base = _make_u8((height // 2, (width + pad) // 2, 2))
    uv = uv_base[:, : width // 2, :]

    frame = VideoFrame.from_dlpack((y, uv), format="nv12")

    assert frame.planes[0].line_size == width + pad
    assert frame.planes[1].line_size == width + pad
    assert frame.planes[0].buffer_size == (width + pad) * height
    assert frame.planes[1].buffer_size == (width + pad) * (height // 2)

    y_plane = _plane_to_2d(frame.planes[0], height, width, numpy.uint8)
    uv_plane = _plane_to_2d(frame.planes[1], height // 2, width, numpy.uint8)
    assertNdarraysEqual(y_plane, y)
    assertNdarraysEqual(uv_plane, uv.reshape(height // 2, width))

    assert frame.planes[0].__dlpack_device__() == (1, 0)

    y_dl = numpy.from_dlpack(frame.planes[0])
    uv_dl = numpy.from_dlpack(frame.planes[1])

    assert y_dl.shape == (height, width)
    assert y_dl.dtype == numpy.uint8
    assert y_dl.strides == (width + pad, 1)
    assertNdarraysEqual(y_dl, y)

    assert uv_dl.shape == (height // 2, width // 2, 2)
    assert uv_dl.dtype == numpy.uint8
    assert uv_dl.strides == (width + pad, 2, 1)
    assertNdarraysEqual(uv_dl, uv)

    expected_y = numpy.array(y, copy=True)
    expected_uv = numpy.array(uv, copy=True)

    del frame
    del y
    del uv
    del y_base
    del uv_base
    gc.collect()

    assertNdarraysEqual(y_dl, expected_y)
    assertNdarraysEqual(uv_dl, expected_uv)


def test_video_frame_from_dlpack_nv12_cpu_accepts_uv_2d() -> None:
    width, height = 64, 48
    y = _make_u8((height, width))
    uv2d = _make_u8((height // 2, width))

    frame = VideoFrame.from_dlpack((y, uv2d), format="nv12")

    uv_plane = _plane_to_2d(frame.planes[1], height // 2, width, numpy.uint8)
    assertNdarraysEqual(uv_plane, uv2d)

    uv_dl = numpy.from_dlpack(frame.planes[1])
    assert uv_dl.shape == (height // 2, width // 2, 2)
    assertNdarraysEqual(uv_dl, uv2d.reshape(height // 2, width // 2, 2))


def test_video_frame_from_dlpack_accepts_video_plane_objects() -> None:
    width, height = 64, 48
    y = _make_u8((height, width))
    uv = _make_u8((height // 2, width // 2, 2))

    frame1 = VideoFrame.from_dlpack((y, uv), format="nv12")
    frame2 = VideoFrame.from_dlpack((frame1.planes[0], frame1.planes[1]), format="nv12")

    assert bytes(frame2.planes[0]) == bytes(frame1.planes[0])
    assert bytes(frame2.planes[1]) == bytes(frame1.planes[1])


@pytest.mark.parametrize("fmt", ["p010le", "p016le"])
def test_video_frame_from_dlpack_p010_p016_cpu(fmt: str) -> None:
    width, height = 64, 48
    y = _make_u16((height, width))
    uv = _make_u16((height // 2, width // 2, 2))

    frame = VideoFrame.from_dlpack((y, uv), format=fmt)

    assert frame.format.name == fmt
    assert len(frame.planes) == 2
    assert frame.planes[0].line_size == width * 2
    assert frame.planes[1].line_size == width * 2

    y_plane = _plane_to_2d(frame.planes[0], height, width, numpy.uint16)
    uv_plane = _plane_to_2d(frame.planes[1], height // 2, width, numpy.uint16)
    assertNdarraysEqual(y_plane, y)
    assertNdarraysEqual(uv_plane, uv.reshape(height // 2, width))

    y_dl = numpy.from_dlpack(frame.planes[0])
    uv_dl = numpy.from_dlpack(frame.planes[1])

    assert y_dl.dtype == numpy.uint16
    assert y_dl.shape == (height, width)
    assert y_dl.strides == (width * 2, 2)
    assertNdarraysEqual(y_dl, y)

    assert uv_dl.dtype == numpy.uint16
    assert uv_dl.shape == (height // 2, width // 2, 2)
    assert uv_dl.strides == (width * 2, 4, 2)
    assertNdarraysEqual(uv_dl, uv)


def test_video_plane_dlpack_export_keeps_frame_alive_after_gc() -> None:
    container = av.open(fate_png())
    frame = next(container.decode(video=0))
    frame_nv12 = frame.reformat(format="nv12")

    width = frame_nv12.width
    height = frame_nv12.height
    line_size = frame_nv12.planes[0].line_size
    expected = _plane_to_2d(frame_nv12.planes[0], height, width, numpy.uint8).copy()

    y_dl = numpy.from_dlpack(frame_nv12.planes[0])
    assert y_dl.shape == (height, width)
    assert y_dl.strides == (line_size, 1)

    del frame_nv12
    del frame
    del container
    gc.collect()

    assertNdarraysEqual(y_dl, expected)


def test_video_plane_dlpack_export_packed_rgb_cpu() -> None:
    # Packed formats interleave several components in one plane and export as
    # a 3D (H, W, C) tensor (issue #2217).
    rgb = (numpy.arange(16 * 24 * 3) % 251).astype(numpy.uint8).reshape(16, 24, 3)
    frame = VideoFrame.from_ndarray(rgb, format="rgb24")
    plane = frame.planes[0]
    assert plane.__dlpack_device__() == (1, 0)

    arr = numpy.from_dlpack(plane)
    assert arr.shape == (16, 24, 3)
    assert arr.strides == (plane.line_size, 3, 1)
    assert arr.dtype == numpy.uint8
    assertNdarraysEqual(arr, rgb)


def test_video_plane_dlpack_export_planar_yuv_cpu() -> None:
    # Planar formats expose each single-component plane as a 2D (H, W) tensor
    # (issue #2217).
    frame = VideoFrame(16, 16, "yuv420p")
    for index, (h, w) in enumerate([(16, 16), (8, 8), (8, 8)]):
        plane = frame.planes[index]
        assert plane.__dlpack_device__() == (1, 0)
        arr = numpy.from_dlpack(plane)
        assert arr.shape == (h, w)
        assert arr.strides == (plane.line_size, 1)
        assert arr.dtype == numpy.uint8


def test_video_plane_dlpack_export_planar_yuv16_cpu() -> None:
    # 16-bit planar formats export as uint16.
    frame = VideoFrame(16, 16, "yuv420p10le")
    arr = numpy.from_dlpack(frame.planes[0])
    assert arr.shape == (16, 16)
    assert arr.dtype == numpy.uint16


def test_video_plane_dlpack_unsupported_format_raises() -> None:
    # Palette formats still cannot be exported.
    frame = VideoFrame(16, 16, "pal8")
    assert frame.planes[0].__dlpack_device__() == (1, 0)

    with pytest.raises(
        NotImplementedError,
        match="bitstream, palette, and Bayer formats are not supported",
    ):
        frame.planes[0].__dlpack__()


def test_sw_format_none_for_software_frame() -> None:
    assert VideoFrame(16, 16, "yuv420p").sw_format is None


def test_video_frame_from_dlpack_requires_two_planes() -> None:
    y = numpy.zeros((4, 4), dtype=numpy.uint8)
    with pytest.raises(ValueError, match="2-plane"):
        VideoFrame.from_dlpack(y, format="nv12")


def test_video_frame_from_dlpack_rejects_packed_format() -> None:
    # Packed formats interleave several components in one plane and cannot be
    # imported (only planar single-component formats and the nv12 family are).
    rgb = numpy.zeros((16, 16, 3), dtype=numpy.uint8)

    with pytest.raises(NotImplementedError, match="is not supported"):
        VideoFrame.from_dlpack((rgb,), format="rgb24")


@pytest.mark.parametrize(
    "fmt,dtype,planes_hw",
    [
        ("yuv420p", numpy.uint8, [(48, 64), (24, 32), (24, 32)]),
        ("yuv422p", numpy.uint8, [(48, 64), (48, 32), (48, 32)]),
        ("yuv444p", numpy.uint8, [(48, 64), (48, 64), (48, 64)]),
        ("gray", numpy.uint8, [(48, 64)]),
        ("yuv420p10le", numpy.uint16, [(48, 64), (24, 32), (24, 32)]),
    ],
)
def test_video_frame_from_dlpack_planar_cpu(fmt, dtype, planes_hw) -> None:
    # Issue #2217: planar formats whose planes each hold one component round
    # trip through DLPack without a NumPy intermediate.
    width, height = 64, 48
    make = _make_u16 if dtype == numpy.uint16 else _make_u8
    src = [make((h, w)) for (h, w) in planes_hw]

    frame = VideoFrame.from_dlpack(tuple(src), format=fmt)

    assert frame.format.name == fmt
    assert frame.width == width and frame.height == height
    assert len(frame.planes) == len(src)

    for i, plane in enumerate(frame.planes):
        arr = numpy.from_dlpack(plane)
        assert arr.dtype == dtype
        assert arr.shape == planes_hw[i]
        assertNdarraysEqual(arr, src[i])


def test_video_frame_from_dlpack_yuv420p_zero_copy_and_lifetime() -> None:
    width, height = 64, 48
    y = _make_u8((height, width))
    u = _make_u8((height // 2, width // 2))
    v = _make_u8((height // 2, width // 2))

    frame = VideoFrame.from_dlpack((y, u, v), format="yuv420p")

    # Mutating the source is visible through the frame (zero copy).
    y[0, 0] = 200
    assert memoryview(frame.planes[0])[0] == 200

    expected = [y.copy(), u.copy(), v.copy()]
    del y, u, v
    gc.collect()

    for i, plane in enumerate(frame.planes):
        assertNdarraysEqual(numpy.from_dlpack(plane), expected[i])


def test_video_frame_from_dlpack_yuv420p_with_pitch() -> None:
    width, height = 64, 48
    pad = 16

    y = _make_u8((height, width + pad))[:, :width]
    u = _make_u8((height // 2, (width + pad) // 2))[:, : width // 2]
    v = _make_u8((height // 2, (width + pad) // 2))[:, : width // 2]

    frame = VideoFrame.from_dlpack((y, u, v), format="yuv420p")

    assert frame.planes[0].line_size == width + pad
    assert frame.planes[1].line_size == (width + pad) // 2
    assertNdarraysEqual(numpy.from_dlpack(frame.planes[0]), y)
    assertNdarraysEqual(numpy.from_dlpack(frame.planes[1]), u)
    assertNdarraysEqual(numpy.from_dlpack(frame.planes[2]), v)


def test_video_frame_from_dlpack_planar_wrong_plane_count() -> None:
    y = numpy.zeros((48, 64), dtype=numpy.uint8)
    u = numpy.zeros((24, 32), dtype=numpy.uint8)

    with pytest.raises(ValueError, match=r"requires 3 plane\(s\), got 2"):
        VideoFrame.from_dlpack((y, u), format="yuv420p")


def test_video_frame_from_dlpack_planar_rejects_odd_dimensions() -> None:
    y = numpy.zeros((48, 63), dtype=numpy.uint8)
    u = numpy.zeros((24, 32), dtype=numpy.uint8)
    v = numpy.zeros((24, 32), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="must be even"):
        VideoFrame.from_dlpack((y, u, v), format="yuv420p")


def test_video_frame_from_dlpack_planar_rejects_palette() -> None:
    idx = numpy.zeros((16, 16), dtype=numpy.uint8)

    with pytest.raises(NotImplementedError, match="palette"):
        VideoFrame.from_dlpack((idx,), format="pal8")


def test_video_frame_from_dlpack_rejects_device_id_for_cpu() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="device_id must be 0 for CPU tensors"):
        VideoFrame.from_dlpack((y, uv), format="nv12", device_id=1)


def test_video_frame_from_dlpack_requires_both_width_height_or_neither() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="either specify both width/height or neither"):
        VideoFrame.from_dlpack((y, uv), format="nv12", width=width, height=0)


def test_video_frame_from_dlpack_rejects_plane0_shape_mismatch_with_width_height() -> (
    None
):
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="plane 0 shape does not match width/height"):
        VideoFrame.from_dlpack((y, uv), format="nv12", width=width + 2, height=height)


def test_video_frame_from_dlpack_rejects_odd_dimensions() -> None:
    width, height = 63, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="width/height must be even"):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_rejects_noncontiguous_plane0_last_dim() -> None:
    width, height = 64, 48
    y_full = numpy.zeros((height, width * 2), dtype=numpy.uint8)
    y = y_full[:, ::2]
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    with pytest.raises(
        ValueError, match="plane 0 must be contiguous in the last dimension"
    ):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_rejects_noncontiguous_uv_plane_last_dim_2d() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv_full = numpy.zeros((height // 2, width * 2), dtype=numpy.uint8)
    uv = uv_full[:, ::2]

    with pytest.raises(
        ValueError, match="plane 1 must be contiguous in the last dimension"
    ):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_rejects_unexpected_uv_strides_3d() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv_full = numpy.zeros((height // 2, width // 2, 4), dtype=numpy.uint8)
    uv = uv_full[:, :, :2]

    with pytest.raises(ValueError, match="unexpected UV plane strides"):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_rejects_wrong_dtype_plane0() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint16)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    with pytest.raises(TypeError, match="unexpected dtype for plane 0"):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_rejects_wrong_dtype_plane1() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint16)

    with pytest.raises(TypeError, match="unexpected dtype for plane 1"):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_p010le_requires_uint16() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    with pytest.raises(TypeError, match="unexpected dtype for plane 0"):
        VideoFrame.from_dlpack((y, uv), format="p010le")


def test_video_frame_from_dlpack_rejects_plane0_ndim_not_2() -> None:
    y = numpy.zeros((4, 4, 1), dtype=numpy.uint8)
    uv = numpy.zeros((2, 4), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="plane 0 must be 2D"):
        VideoFrame.from_dlpack((y, uv), format="nv12", width=4, height=4)


def test_video_frame_from_dlpack_rejects_plane1_ndim_not_2_or_3() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width, 1, 1), dtype=numpy.uint8)

    with pytest.raises(ValueError, match="plane 1 must be 2D or 3D"):
        VideoFrame.from_dlpack((y, uv), format="nv12")


def test_video_frame_from_dlpack_reusing_capsule_raises_typeerror() -> None:
    width, height = 64, 48
    y = numpy.zeros((height, width), dtype=numpy.uint8)
    uv = numpy.zeros((height // 2, width // 2, 2), dtype=numpy.uint8)

    cap0 = y.__dlpack__()
    cap1 = uv.__dlpack__()

    VideoFrame.from_dlpack((cap0, cap1), format="nv12", width=width, height=height)

    with pytest.raises(TypeError, match="expected a DLPack capsule"):
        VideoFrame.from_dlpack((cap0, cap1), format="nv12", width=width, height=height)


def test_video_frame_from_dlpack_invalid_plane_object_raises_typeerror() -> None:
    with pytest.raises(TypeError, match="expected a DLPack capsule"):
        VideoFrame.from_dlpack((object(), object()), format="nv12", width=64, height=48)


def test_cuda_context_flags() -> None:
    default_ctx = av.video.frame.CudaContext()
    assert default_ctx.primary_ctx is True
    assert default_ctx.current_ctx is False

    with pytest.raises(ValueError, match="mutually exclusive"):
        av.video.frame.CudaContext(primary_ctx=True, current_ctx=True)

    ctx = av.video.frame.CudaContext(primary_ctx=False, current_ctx=True)
    assert ctx.primary_ctx is False
    assert ctx.current_ctx is True


def test_video_frame_from_dlpack_cuda_hw_frame_behavior_if_available() -> None:
    backend = _get_cuda_backend()
    if backend is None:
        pytest.skip("CUDA backend (cupy/torch) not available.")

    width, height = 64, 48
    name, mod = backend

    try:
        if name == "cupy":
            try:
                ndev = int(mod.cuda.runtime.getDeviceCount())
            except Exception:
                ndev = 1

            device_id = 1 if ndev > 1 else 0
            with mod.cuda.Device(device_id):
                y = mod.arange(height * width, dtype=mod.uint8).reshape(height, width)
                uv = mod.arange(
                    (height // 2) * (width // 2) * 2, dtype=mod.uint8
                ).reshape(height // 2, width // 2, 2)
                expected_device = y.__dlpack_device__()
                frame = VideoFrame.from_dlpack((y, uv), format="nv12")

                assert frame.format.name == "cuda"
                assert len(frame.planes) == 2

                with pytest.raises(
                    TypeError, match="Hardware frame planes do not support"
                ):
                    memoryview(frame.planes[0])

                assert frame.planes[0].__dlpack_device__() == expected_device

                cap_y = frame.planes[0].__dlpack__()
                if hasattr(mod, "fromDlpack"):
                    y2 = mod.fromDlpack(cap_y)
                else:
                    y2 = mod.from_dlpack(cap_y)

                assert y2.shape == y.shape
                assert mod.all(y2 == y).item()

                with pytest.raises(
                    ValueError,
                    match="Cannot convert a hardware frame to numpy directly",
                ):
                    frame.to_ndarray(format="cuda")

        else:
            try:
                ndev = int(mod.cuda.device_count())
            except Exception:
                ndev = 1

            device_id = 1 if ndev > 1 else 0
            device = f"cuda:{device_id}"

            y = mod.arange(height * width, device=device, dtype=mod.uint8).reshape(
                height, width
            )
            uv = mod.arange(
                (height // 2) * (width // 2) * 2, device=device, dtype=mod.uint8
            ).reshape(height // 2, width // 2, 2)

            expected_device = y.__dlpack_device__()
            frame = VideoFrame.from_dlpack((y, uv), format="nv12")

            assert frame.format.name == "cuda"
            assert len(frame.planes) == 2

            with pytest.raises(TypeError, match="Hardware frame planes do not support"):
                memoryview(frame.planes[0])

            assert frame.planes[0].__dlpack_device__() == expected_device

            cap_y = frame.planes[0].__dlpack__()
            y2 = mod.utils.dlpack.from_dlpack(cap_y)

            assert tuple(y2.shape) == tuple(y.shape)
            assert mod.equal(y2, y)

            with pytest.raises(
                ValueError, match="Cannot convert a hardware frame to numpy directly"
            ):
                frame.to_ndarray(format="cuda")
    except av.FFmpegError as e:
        pytest.skip(f"CUDA hwcontext not available in this build/runtime: {e}")


@pytest.mark.parametrize(
    "use_current_ctx", [False, True], ids=["primary-context", "current-context"]
)
def test_encode_cuda_frame_with_nvenc_if_available(use_current_ctx: bool) -> None:
    # Issue #2199: a CUDA frame from DLPack should encode on the GPU directly.
    # Its hw_frames_ctx must propagate to the encoder before avcodec_open2.
    backend = _get_cuda_backend()
    if backend is None:
        pytest.skip("CUDA backend (cupy/torch) not available.")

    name, mod = backend
    width, height = 256, 256

    try:
        if name == "torch":
            y = mod.zeros((height, width), dtype=mod.uint8, device="cuda")
            uv = mod.zeros((height // 2, width // 2, 2), dtype=mod.uint8, device="cuda")
        else:
            y = mod.zeros((height, width), dtype=mod.uint8)
            uv = mod.zeros((height // 2, width // 2, 2), dtype=mod.uint8)

        if use_current_ctx:
            current_ctx = av.video.frame.CudaContext(
                device_id=int(y.__dlpack_device__()[1]),
                primary_ctx=False,
                current_ctx=True,
            )
            frame = VideoFrame.from_dlpack(
                (y, uv), format="nv12", cuda_context=current_ctx
            )
        else:
            frame = VideoFrame.from_dlpack((y, uv), format="nv12")
        assert frame.format.name == "cuda"
        assert frame.sw_format is not None and frame.sw_format.name == "nv12"

        cc = av.CodecContext.create("h264_nvenc", "w")
        cc.width = width
        cc.height = height
        cc.time_base = Fraction(1, 24)
        cc.framerate = Fraction(24, 1)
        cc.pix_fmt = "cuda"

        packets = cc.encode(frame)
        packets += cc.encode(None)  # flush
        assert any(p.size for p in packets)
    except av.FFmpegError as e:
        pytest.skip(f"nvenc/CUDA not available in this build/runtime: {e}")
