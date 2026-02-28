__all__ = ("DeviceInfo", "enumerate_input_devices", "enumerate_output_devices")

class DeviceInfo:
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
    ) -> None: ...
    def __repr__(self) -> str: ...

def enumerate_input_devices(format_name: str) -> list[DeviceInfo]: ...
def enumerate_output_devices(format_name: str) -> list[DeviceInfo]: ...
