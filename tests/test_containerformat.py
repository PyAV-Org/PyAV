from .common import *
from av.format import ContainerFormat, names


class TestContainerFormats(TestCase):

    def test_matroska(self):
        fmt = ContainerFormat('matroska')
        self.assertTrue(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, 'matroska')
        self.assertEqual(fmt.long_name, 'Matroska')
        self.assertIn('mkv', fmt.extensions)

    def test_mov(self):
        fmt = ContainerFormat('mov')
        self.assertTrue(fmt.is_input)
        self.assertTrue(fmt.is_output)
        self.assertEqual(fmt.name, 'mov')
        self.assertEqual(fmt.long_name, 'QuickTime / MOV')

