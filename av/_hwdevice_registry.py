_cuda_hwdevice_data_ptr_to_device_id: dict[int, int] = {}


def register_cuda_hwdevice_data_ptr(hwdevice_data_ptr: int, device_id: int) -> None:
    if hwdevice_data_ptr:
        _cuda_hwdevice_data_ptr_to_device_id[int(hwdevice_data_ptr)] = int(device_id)


def lookup_cuda_device_id(hwdevice_data_ptr: int) -> int:
    if not hwdevice_data_ptr:
        return 0
    return _cuda_hwdevice_data_ptr_to_device_id.get(int(hwdevice_data_ptr), 0)
