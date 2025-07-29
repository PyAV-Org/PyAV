from av import ContainerFormat
from av.option import Option, OptionType


class TestOptions:
    def test_mov_options(self) -> None:
        mov = ContainerFormat("mov")
        options = mov.descriptor.options  # type: ignore
        by_name = {opt.name: opt for opt in options}

        opt = by_name.get("use_absolute_path")

        assert isinstance(opt, Option)
        assert opt.name == "use_absolute_path"

        # This was not a good option to actually test.
        assert opt.type in (OptionType.BOOL, OptionType.INT)
