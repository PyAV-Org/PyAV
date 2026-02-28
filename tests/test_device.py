import sys

import pytest

import av.error
from av.device import DeviceInfo, enumerate_input_devices, enumerate_output_devices


def test_device_info_attributes() -> None:
    d = DeviceInfo("0", "FaceTime HD Camera", True, ["video"])
    assert d.name == "0"
    assert d.description == "FaceTime HD Camera"
    assert d.is_default is True
    assert d.media_types == ["video"]


def test_device_info_repr_default() -> None:
    d = DeviceInfo("0", "FaceTime HD Camera", True, ["video"])
    assert repr(d) == "<av.DeviceInfo '0' 'FaceTime HD Camera' (default)>"


def test_device_info_repr_non_default() -> None:
    d = DeviceInfo("1", "Built-in Microphone", False, ["audio"])
    assert repr(d) == "<av.DeviceInfo '1' 'Built-in Microphone'>"


def test_enumerate_input_devices_unknown_format() -> None:
    with pytest.raises(ValueError, match="no such input format"):
        enumerate_input_devices("not_a_real_format_xyz")


def test_enumerate_output_devices_unknown_format() -> None:
    with pytest.raises(ValueError, match="no such output format"):
        enumerate_output_devices("not_a_real_format_xyz")


def _assert_valid_device_list(devices: list[DeviceInfo]) -> None:
    assert isinstance(devices, list)
    for device in devices:
        assert isinstance(device, DeviceInfo)
        assert isinstance(device.name, str)
        assert isinstance(device.description, str)
        assert isinstance(device.is_default, bool)
        assert isinstance(device.media_types, list)
        assert all(isinstance(mt, str) for mt in device.media_types)


@pytest.mark.skipif(sys.platform != "darwin", reason="avfoundation is macOS only")
def test_enumerate_input_devices_avfoundation() -> None:
    _assert_valid_device_list(enumerate_input_devices("avfoundation"))


@pytest.mark.skipif(sys.platform != "linux", reason="v4l2 is Linux only")
def test_enumerate_input_devices_v4l2() -> None:
    try:
        _assert_valid_device_list(enumerate_input_devices("video4linux2"))
    except av.error.OSError:
        pytest.skip("v4l2 device enumeration not available")


@pytest.mark.skipif(sys.platform != "win32", reason="dshow is Windows only")
def test_enumerate_input_devices_dshow() -> None:
    try:
        _assert_valid_device_list(enumerate_input_devices("dshow"))
    except av.error.OSError:
        pytest.skip("dshow device enumeration not available")
