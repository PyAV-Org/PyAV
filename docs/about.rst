More About PyAV
===============

Bring your own FFmpeg
---------------------

PyAV does not bundle FFmpeg, and while it must be built for the specific FFmpeg version installed it does not require a specific version.

We automatically detect the differences that we depended on at build time. This is a fairly trial-and-error process, so please let us know if something won't compile due to missing functions or members.

Additionally, we are far from wrapping the full extents of the libraries. There are many functions and C struct members which are currently unexposed.


Dropping Libav
--------------

Until mid-2018 PyAV supported either FFmpeg_ or Libav_. The split support in the community essentially required we do so. That split has largely been resolved as distributions have returned to shipping FFmpeg instead of Libav.

While we could have theoretically continued to support both, it has been years since automated testing of PyAV with Libav passed, and we received zero complaints. Supporting both also restricted us to using the subset of both, which was starting to erode at the cleanliness of PyAV.

Many Libav-isms remain in PyAV, and we will slowly scrub them out to clean up PyAV as we come across them again.

