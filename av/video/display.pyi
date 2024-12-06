from av.sidedata.sidedata import SideData

def get_display_rotation(matrix: SideData) -> float:
    """Extract the rotation component of the `DISPLAYMATRIX` transformation matrix.

    Args:
        matrix (SideData): The transformation matrix.

    Returns:
        float: The angle (in degrees) by which the transformation rotates the frame
               counterclockwise. The angle will be in range [-180.0, 180.0].

    Note:
        Floating point numbers are inherently inexact, so callers are
        recommended to round the return value to the nearest integer before use.
    """
