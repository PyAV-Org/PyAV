import re

import cython
import cython.cimports.libav as lib
from cython.cimports.av.error import err_check


class DeviceInfo:
    """Information about an input or output device.

    :param str name: The device identifier, for use as the first argument to :func:`av.open`.
    :param str description: Human-readable description of the device.
    :param bool is_default: Whether this is the default device.
    :param list media_types: Media types this device provides, e.g. ``["video"]``, ``["audio"]``,
        or ``["video", "audio"]``.

    """

    name: str
    description: str
    is_default: bool
    media_types: list[str]

    def __init__(
        self,
        name: str,
        description: str,
        is_default: bool,
        media_types: list[str],
    ) -> None:
        self.name = name
        self.description = description
        self.is_default = is_default
        self.media_types = media_types

    def __repr__(self) -> str:
        default = " (default)" if self.is_default else ""
        return f"<av.DeviceInfo {self.name!r} {self.description!r}{default}>"


@cython.cfunc
def _build_device_list(device_list: cython.pointer[lib.AVDeviceInfoList]) -> list:
    devices: list = []
    i: cython.int
    j: cython.int
    device_info: cython.pointer[lib.AVDeviceInfo]
    mt: lib.AVMediaType
    s: cython.p_const_char

    for i in range(device_list.nb_devices):
        device_info = device_list.devices[i]

        media_types: list = []
        for j in range(device_info.nb_media_types):
            mt = device_info.media_types[j]
            s = lib.av_get_media_type_string(mt)
            if s:
                media_types.append(s.decode())

        devices.append(
            DeviceInfo(
                name=device_info.device_name.decode()
                if device_info.device_name
                else "",
                description=device_info.device_description.decode()
                if device_info.device_description
                else "",
                is_default=(i == device_list.default_device),
                media_types=media_types,
            )
        )

    return devices


def _enumerate_via_log_fallback(format_name: str) -> list[DeviceInfo]:
    """Fallback for formats (e.g. avfoundation) that log devices instead of
    implementing get_device_list. Opens the format with list_devices=1 and
    parses the INFO log output."""
    from av import logging as avlogging

    fmt: cython.pointer[cython.const[lib.AVInputFormat]] = lib.av_find_input_format(
        format_name
    )

    opts: cython.pointer[lib.AVDictionary] = cython.NULL
    lib.av_dict_set(cython.address(opts), b"list_devices", b"1", 0)

    ctx: cython.pointer[lib.AVFormatContext] = cython.NULL

    # Temporarily enable INFO logging so Capture receives device list messages.
    old_level = avlogging.get_level()
    avlogging.set_level(avlogging.INFO)
    devices: list[DeviceInfo] = []
    try:
        with avlogging.Capture() as logs:
            lib.avformat_open_input(cython.address(ctx), b"", fmt, cython.address(opts))
            if ctx:
                lib.avformat_close_input(cython.address(ctx))

        current_media_type = "video"
        for _level, _name, message in logs:
            message = message.strip()
            if "video devices" in message.lower():
                current_media_type = "video"
            elif "audio devices" in message.lower():
                current_media_type = "audio"
            else:
                m = re.match(r"\[(\d+)\] (.+)", message)
                if m:
                    devices.append(
                        DeviceInfo(
                            name=m.group(1),
                            description=m.group(2),
                            is_default=False,
                            media_types=[current_media_type],
                        )
                    )
    finally:
        avlogging.set_level(old_level)
        lib.av_dict_free(cython.address(opts))

    return devices


def enumerate_input_devices(format_name: str) -> list[DeviceInfo]:
    """List the available input devices for a given format.

    :param str format_name: The format name, e.g. ``"avfoundation"``, ``"dshow"``, ``"v4l2"``.
    :rtype: list[DeviceInfo]
    :raises ValueError: If *format_name* is not a known input format.
    :raises av.FFmpegError: If the device does not support enumeration.

    Example::

        for device in av.enumerate_input_devices("avfoundation"):
            print(device.name, device.description)

    """
    fmt: cython.pointer[cython.const[lib.AVInputFormat]] = lib.av_find_input_format(
        format_name
    )
    if not fmt:
        raise ValueError(f"no such input format: {format_name!r}")

    device_list: cython.pointer[lib.AVDeviceInfoList] = cython.NULL
    try:
        err_check(
            lib.avdevice_list_input_sources(
                fmt, cython.NULL, cython.NULL, cython.address(device_list)
            )
        )
        return _build_device_list(device_list)
    except NotImplementedError:
        # Format doesn't implement get_device_list (e.g. avfoundation).
        # Fall back to opening with list_devices=1 and parsing the log output.
        return _enumerate_via_log_fallback(format_name)
    finally:
        lib.avdevice_free_list_devices(cython.address(device_list))


def enumerate_output_devices(format_name: str) -> list[DeviceInfo]:
    """List the available output devices for a given format.

    :param str format_name: The format name, e.g. ``"audiotoolbox"``.
    :rtype: list[DeviceInfo]
    :raises ValueError: If *format_name* is not a known output format.
    :raises av.FFmpegError: If the device does not support enumeration.

    """
    fmt: cython.pointer[cython.const[lib.AVOutputFormat]] = lib.av_guess_format(
        format_name, cython.NULL, cython.NULL
    )
    if not fmt:
        raise ValueError(f"no such output format: {format_name!r}")

    device_list: cython.pointer[lib.AVDeviceInfoList] = cython.NULL
    err_check(
        lib.avdevice_list_output_sinks(
            fmt, cython.NULL, cython.NULL, cython.address(device_list)
        )
    )

    try:
        return _build_device_list(device_list)
    finally:
        lib.avdevice_free_list_devices(cython.address(device_list))
