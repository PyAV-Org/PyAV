from typing import Literal

from av.stream import Stream

class AttachmentStream(Stream):
    type: Literal["attachment"]
    @property
    def mimetype(self) -> str | None: ...
