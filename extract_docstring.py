import sys

from Cython import Utils
from Cython.Compiler import Parsing
from Cython.Compiler.Scanning import PyrexScanner

class mock_scope(object):
    included_files = []

class mock_context(object):
    options = object()
    language_level = 2
    future_directives = []

class source_desc(object):

    def is_python_file(self):
        return False


f = Utils.open_source_file(sys.argv[1], "rU")
s = PyrexScanner(f, source_desc(), # Was `source_desc`.
        source_encoding=f.encoding,
        scope=mock_scope, # Was `scope`.
        context=mock_context, # Was `self`.
)
tree = Parsing.p_module(s, None, 'full.module.name') # Was `pxd`.