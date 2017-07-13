import io
import random

try:
    from common import *
except ImportError:
    from .common import *


class TestRandomInput(TestCase):
    
    def test_random_input(self):
        random_data = ''.join(map(chr, [random.randint(0, 127) for _ in range(1024)])).encode('latin-1')
        with self.assertRaises(av.AVError):
            av.open(io.BytesIO(random_data))
