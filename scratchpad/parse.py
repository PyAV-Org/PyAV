from Cython.Compiler.Main import compile_single, CompilationOptions
from Cython.Compiler.TreeFragment import parse_from_strings
from Cython.Compiler.Visitor import TreeVisitor

options = CompilationOptions()
options.include_path.append('include')
options.language_level = 2
options.compiler_directives = dict(
    c_string_type='str',
    c_string_encoding='ascii',
)

ctx = options.create_context()

tree = parse_from_strings('av.packet', open('av/dictionary.pyx').read().decode('utf8'), ctx)

class Visitor(TreeVisitor):

    def __init__(self):
        super(Visitor, self).__init__()
        self.current_class = None
        self.current_func = None
        self.current_property = None
        self.current_module = None

    def visit_Node(self, node):
        self.visitchildren(node)

    def visit_ModuleNode(self, node):
        self.current_module = node.full_module_name
        self.visitchildren(node)

    def visit_CClassDefNode(self, node):
        self.current_class = node.class_name
        self.visitchildren(node)
        self.current_class = None

    def visit_PropertyNode(self, node):
        self.current_property = node.name
        self.visitchildren(node)
        self.current_property = None

    def visit_DefNode(self, node):
        self.current_func = node.name
        self.visitchildren(node)
        self.current_func = None

    def visit_AttributeNode(self, node):
        if getattr(node.obj, 'name', None) == 'lib':
            print 'line %s, char %s: %s:%s.%s -> %s' % (
                node.pos[1], node.pos[2],
                self.current_module,
                self.current_class,
                self.current_property or self.current_func,
                node.attribute
            )
        self.visitchildren(node)


Visitor().visit(tree)

#print tree.dump()
