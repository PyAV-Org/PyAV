from av import ContainerFormat
from av.option import Option, OptionType

from .common import TestCase


class TestOptions(TestCase):
    def test_mov_options(self):
        mov = ContainerFormat("mov")
        options = mov.descriptor.options
        by_name = {opt.name: opt for opt in options}

        opt = by_name.get("use_absolute_path")

        self.assertIsInstance(opt, Option)
        self.assertEqual(opt.name, "use_absolute_path")

        # This was not a good option to actually test.
        self.assertIn(opt.type, (OptionType.BOOL, OptionType.INT))
