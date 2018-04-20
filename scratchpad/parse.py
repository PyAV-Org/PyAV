from __future__ import print_function
from Cython.Compiler.Main import compile_single, CompilationOptions
from Cython.Compiler.TreeFragment import parse_from_strings
from Cython.Compiler.Visitor import TreeVisitor
from Cython.Compiler import Nodes
from Cython.Compiler.AutoDocTransforms import EmbedSignature

options = CompilationOptions()
options.include_path.append('include')
options.language_level = 2
options.compiler_directives = dict(
    c_string_type='str',
    c_string_encoding='ascii',
)

ctx = options.create_context()

tree = parse_from_strings('include.libavutil.avutil', open('scratchpad/test.pxd').read().decode('utf8'), ctx)

class Visitor(TreeVisitor):

    def __init__(self, state=None):
        super(Visitor, self).__init__()
        self.state = dict(state or {})
        self.events = []

    def record_event(self, node, **kw):
        state = self.state.copy()
        state.update(**kw)
        state['pos'] = node.pos
        state['end_pos'] = node.end_pos()
        self.events.append(state)

    def visit_Node(self, node):
        self.visitchildren(node)

    def visit_CDefExternNode(self, node):
        self.state['extern_from'] = node.include_file
        self.visitchildren(node)
        self.state.pop('extern_from')

    def visit_CStructOrUnionDefNode(self, node):
        self.record_event(node, struct=node.name)
        # self.visitchildren(node)

    def visit_CFuncDeclaratorNode(self, node):
        if isinstance(node.base, Nodes.CNameDeclaratorNode):
            self.record_event(node, function=node.base.name)
            print(EmbedSignature(ctx)._fmt_arglist(node.args))
        else:
            self.visitchildren(node)

    def visit_CVarDefNode(self, node):
        if isinstance(node.declarators[0], Nodes.CNameDeclaratorNode):
            self.record_event(node, variable=node.declarators[0].name)
        else:
            self.visitchildren(node)


v = Visitor()
v.visit(tree)
for e in v.events:
    pass
    #print e

#print tree.dump()
