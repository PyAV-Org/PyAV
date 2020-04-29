import json
import os
import re
import sys

import xml.etree.ElementTree as etree

from Cython.Compiler.Main import compile_single, CompilationOptions
from Cython.Compiler.TreeFragment import parse_from_strings
from Cython.Compiler.Visitor import TreeVisitor
from Cython.Compiler import Nodes

os.chdir(os.path.abspath(os.path.join(__file__, '..', '..', '..')))


class Visitor(TreeVisitor):

    def __init__(self, state=None):
        super(Visitor, self).__init__()
        self.state = dict(state or {})
        self.events = []

    def record_event(self, node, **kw):
        state = self.state.copy()
        state.update(**kw)
        state['node'] = node
        state['pos'] = node.pos
        state['end_pos'] = node.end_pos()
        self.events.append(state)

    def visit_Node(self, node):
        self.visitchildren(node)

    def visit_ModuleNode(self, node):
        self.state['module'] = node.full_module_name
        self.visitchildren(node)
        self.state.pop('module')

    def visit_CDefExternNode(self, node):
        self.state['extern_from'] = node.include_file
        self.visitchildren(node)
        self.state.pop('extern_from')

    def visit_CStructOrUnionDefNode(self, node):
        self.record_event(node, type='struct', name=node.name)
        self.state['struct'] = node.name
        self.visitchildren(node)
        self.state.pop('struct')

    def visit_CFuncDeclaratorNode(self, node):
        if isinstance(node.base, Nodes.CNameDeclaratorNode):
            self.record_event(node, type='function', name=node.base.name)
        else:
            self.visitchildren(node)

    def visit_CVarDefNode(self, node):

        if isinstance(node.declarators[0], Nodes.CNameDeclaratorNode):

            # Grab the type name.
            # TODO: Do a better job.
            type_ = node.base_type
            if hasattr(type_, 'name'):
                type_name = type_.name
            elif hasattr(type_, 'base_type'):
                type_name = type_.base_type.name
            else:
                type_name = str(type_)

            self.record_event(node, type='variable', name=node.declarators[0].name,
                vartype=type_name)

        else:
            self.visitchildren(node)

    def visit_CClassDefNode(self, node):
        self.state['class'] = node.class_name
        self.visitchildren(node)
        self.state.pop('class')

    def visit_PropertyNode(self, node):
        self.state['property'] = node.name
        self.visitchildren(node)
        self.state.pop('property')

    def visit_DefNode(self, node):
        self.state['function'] = node.name
        self.visitchildren(node)
        self.state.pop('function')

    def visit_AttributeNode(self, node):
        if getattr(node.obj, 'name', None) == 'lib':
            self.record_event(node, type='use', name=node.attribute)
        else:
            self.visitchildren(node)


def extract(path, **kwargs):

    name = os.path.splitext(os.path.relpath(path))[0].replace('/', '.')

    options = CompilationOptions()
    options.include_path.append('include')
    options.language_level = 2
    options.compiler_directives = dict(
        c_string_type='str',
        c_string_encoding='ascii',
    )

    context = options.create_context()

    tree = parse_from_strings(name, open(path).read(), context,
        level='module_pxd' if path.endswith('.pxd') else None,
        **kwargs)

    extractor = Visitor({'file': path})
    extractor.visit(tree)
    return extractor.events


def iter_cython(path):
    '''Yield all ``.pyx`` and ``.pxd`` files in the given root.'''
    for dir_path, dir_names, file_names in os.walk(path):
        for file_name in file_names:
            if file_name.startswith('.'):
                continue
            if os.path.splitext(file_name)[1] not in ('.pyx', '.pxd'):
                continue
            yield os.path.join(dir_path, file_name)


doxygen = {}
doxygen_base = 'https://ffmpeg.org/doxygen/trunk'
tagfile_path = 'docs/_build/doxygen/tagfile.xml'

tagfile_json = tagfile_path + '.json'
if os.path.exists(tagfile_json):
    print('Loading pre-parsed Doxygen tagfile:', tagfile_json, file=sys.stderr)
    doxygen = json.load(open(tagfile_json))


if not doxygen:

    print('Parsing Doxygen tagfile:', tagfile_path, file=sys.stderr)
    if not os.path.exists(tagfile_path):
        print('    MISSING!', file=sys.stderr)
    else:

        root = etree.parse(tagfile_path)

        def inspect_member(node, name_prefix=''):
            name = name_prefix + node.find('name').text
            anchorfile = node.find('anchorfile').text
            anchor = node.find('anchor').text

            url = '%s/%s#%s' % (doxygen_base, anchorfile, anchor)

            doxygen[name] = {'url': url}

            if node.attrib['kind'] == 'function':
                ret_type = node.find('type').text
                arglist = node.find('arglist').text
                sig = '%s %s%s' % (ret_type, name, arglist)
                doxygen[name]['sig'] = sig

        for struct in root.iter('compound'):
            if struct.attrib['kind'] != 'struct':
                continue
            name_prefix = struct.find('name').text + '.'
            for node in struct.iter('member'):
                inspect_member(node, name_prefix)

        for node in root.iter('member'):
            inspect_member(node)


        json.dump(doxygen, open(tagfile_json, 'w'), sort_keys=True, indent=4)


print('Parsing Cython source for references...', file=sys.stderr)
lib_references = {}
for path in iter_cython('av'):
    try:
        events = extract(path)
    except Exception as e:
        print("    %s in %s" % (e.__class__.__name__, path), file=sys.stderr)
        print("        %s" % e, file=sys.stderr)
        continue
    for event in events:
        if event['type'] == 'use':
            lib_references.setdefault(event['name'], []).append(event)







defs_by_extern = {}
for path in iter_cython('include'):

    # This one has "include" directives, which is not supported when
    # parsing from a string.
    if path == 'include/libav.pxd':
        continue

    # Extract all #: comments from the source files.
    comments_by_line = {}
    for i, line in enumerate(open(path)):
        m = re.match(r'^\s*#: ?', line)
        if m:
            comment = line[m.end():].rstrip()
            comments_by_line[i + 1] = line[m.end():]

    # Extract Cython definitions from the source files.
    for event in extract(path):

        extern = event.get('extern_from') or path.replace('include/', '')
        defs_by_extern.setdefault(extern, []).append(event)

        # Collect comments above and below
        comments = event['_comments'] = []
        line = event['pos'][1] - 1
        while line in comments_by_line:
            comments.insert(0, comments_by_line.pop(line))
            line -= 1
        line = event['end_pos'][1] + 1
        while line in comments_by_line:
            comments.append(comments_by_line.pop(line))
            line += 1

        # Figure out the Sphinx headline.
        if event['type'] == 'function':
            event['_sort_key'] = 2
            sig = doxygen.get(event['name'], {}).get('sig')
            if sig:
                sig = re.sub(r'\).+', ')', sig) # strip trailer
                event['_headline'] = '.. c:function:: %s' % sig
            else:
                event['_headline'] = '.. c:function:: %s()' % event['name']

        elif event['type'] == 'variable':
            struct = event.get('struct')
            if struct:
                event['_headline'] = '.. c:member:: %s %s' % (event['vartype'], event['name'])
                event['_sort_key'] = 1.1
            else:
                event['_headline'] = '.. c:var:: %s' % event['name']
                event['_sort_key'] = 3

        elif event['type'] == 'struct':
            event['_headline'] = '.. c:type:: struct %s' % event['name']
            event['_sort_key'] = 1
            event['_doxygen_url'] = '%s/struct%s.html' % (doxygen_base, event['name'])

        else:
            print('Unknown event type %s' % event['type'], file=sys.stderr)

        name = event['name']
        if event.get('struct'):
            name = '%s.%s' % (event['struct'], name)

        # Doxygen URLs
        event.setdefault('_doxygen_url', doxygen.get(name, {}).get('url'))

        # Find use references.
        ref_events = lib_references.get(name, [])
        if ref_events:

            ref_pairs = []
            for ref in sorted(ref_events, key=lambda e: e['name']):

                chunks = [
                    ref.get('module'),
                    ref.get('class'),
                ]
                chunks = filter(None, chunks)
                prefix = '.'.join(chunks) + '.' if chunks else ''

                if ref.get('property'):
                    ref_pairs.append((ref['property'], ':attr:`%s%s`' % (prefix, ref['property'])))
                elif ref.get('function'):
                    name = ref['function']
                    if name in ('__init__', '__cinit__', '__dealloc__'):
                        ref_pairs.append((name, ':class:`%s%s <%s>`' % (prefix, name, prefix.rstrip('.'))))
                    else:
                        ref_pairs.append((name, ':func:`%s%s`' % (prefix, name)))
                else:
                    continue

            unique_refs = event['_references'] = []
            seen = set()
            for name, ref in sorted(ref_pairs):
                if name in seen:
                    continue
                seen.add(name)
                unique_refs.append(ref)




print('''

..
    This file is generated by includes.py; any modifications will be destroyed!

Wrapped C Types and Functions
=============================

''')

for extern, events in sorted(defs_by_extern.items()):
    did_header = False

    for event in events:

        headline = event.get('_headline')
        comments = event.get('_comments')
        refs = event.get('_references', [])
        url = event.get('_doxygen_url')
        indent = '    ' if event.get('struct') else ''

        if not headline:
            continue
        if (
            not filter(None, (x.strip() for x in comments if x.strip())) and
            not refs and
            event['type'] not in ('struct', )
        ):
            pass

        if not did_header:
            print('``%s``' % extern)
            print('-' * (len(extern) + 4))
            print()
            did_header = True

        if url:
            print()
            print(indent + '.. rst-class:: ffmpeg-quicklink')
            print()
            print(indent + '    `FFmpeg Docs <%s>`__' % url)

        print(indent + headline)
        print()

        if comments:
            for line in comments:
                print(indent + '    ' + line)
            print()

        if refs:
            print(indent + '    Referenced by: ', end='')
            for i, ref in enumerate(refs):
                print((', ' if i else '') + ref, end='')
            print('.')

        print()
