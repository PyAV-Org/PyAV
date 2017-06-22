from av.option import Option

from common import *


class TestOptions(TestCase):

    def test_mov_options(self):

        mov = av.ContainerFormat('mov')
        options = mov.descriptor.options
        by_name = {opt.name: opt for opt in options}

        opt = by_name.get('use_absolute_path')

        self.assertIsInstance(opt, Option)
        self.assertTrue(str(opt).startswith('<av.Option use_absolute_path (BOOL at *0xb4) at 0x'))
        self.assertEqual(opt.name, 'use_absolute_path')
        self.assertEqual(opt.type, 'BOOL')
        self.assertEqual(opt.offset, 0xb4)


