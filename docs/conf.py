import logging
import os
import re
import sys
import xml.etree.ElementTree as etree

from docutils import nodes
from sphinx import addnodes
from sphinx.util.docutils import SphinxDirective
import sphinx


logging.basicConfig()

# If extensions (or modules to document with autodoc) are in another directory,
# add these directories to sys.path here. If the directory is relative to the
# documentation root, use os.path.abspath to make it absolute, like shown here.
sys.path.insert(0, os.path.abspath(".."))

# -- General configuration -----------------------------------------------------

# Add any Sphinx extension module names here, as strings. They can be extensions
# coming with Sphinx (named 'sphinx.ext.*') or your custom ones.
extensions = [
    "sphinx.ext.autodoc",
    "sphinx.ext.intersphinx",
    "sphinx.ext.todo",
    "sphinx.ext.coverage",
    "sphinx.ext.viewcode",
    "sphinx.ext.extlinks",
    "sphinx.ext.doctest",
]


# Add any paths that contain templates here, relative to this directory.
templates_path = ["_templates"]

# The suffix of source filenames.
source_suffix = ".rst"

# The master toctree document.
master_doc = "index"

# General information about the project.
project = "PyAV"
copyright = "2024, The PyAV Team"

# The version info for the project you're documenting, acts as replacement for
# |version| and |release|, also used in various other places throughout the
# built documents.
#
about = {}
with open("../av/about.py") as fp:
    exec(fp.read(), about)

# The full version, including alpha/beta/rc tags.
release = about["__version__"]

# The short X.Y version.
version = release.split("-")[0]

exclude_patterns = ["_build"]

# The name of the Pygments (syntax highlighting) style to use.
pygments_style = "sphinx"

# -- Options for HTML output ---------------------------------------------------

html_theme = "pyav"
html_theme_path = [os.path.abspath(os.path.join(__file__, "..", "_themes"))]

# The name of an image file (relative to this directory) to place at the top
# of the sidebar.
html_logo = "_static/logo-250.png"

# The name of an image file (within the static path) to use as favicon of the
# docs.  This file should be a Windows icon file (.ico) being 16x16 or 32x32
# pixels large.
html_favicon = "_static/favicon.png"

# Add any paths that contain custom static files (such as style sheets) here,
# relative to this directory. They are copied after the builtin static files,
# so a file named "default.css" will overwrite the builtin "default.css".
html_static_path = ["_static"]


doctest_global_setup = """

import errno
import os

import av
from av.datasets import fate, fate as fate_suite, curated

from tests import common
from tests.common import sandboxed as _sandboxed

def sandboxed(*args, **kwargs):
    kwargs['timed'] = True
    return _sandboxed('docs', *args, **kwargs)

_cwd = os.getcwd()
here = sandboxed('__cwd__')
try:
    os.makedirs(here)
except OSError as e:
    if e.errno != errno.EEXIST:
        raise
os.chdir(here)

video_path = curated('pexels/time-lapse-video-of-night-sky-857195.mp4')

"""

doctest_global_cleanup = """

os.chdir(_cwd)

"""


doctest_test_doctest_blocks = ""


extlinks = {
    "ffstruct": ("http://ffmpeg.org/doxygen/trunk/struct%s.html", "struct "),
    "issue": ("https://github.com/PyAV-Org/PyAV/issues/%s", "#"),
    "pr": ("https://github.com/PyAV-Org/PyAV/pull/%s", "#"),
    "gh-user": ("https://github.com/%s", "@"),
}

intersphinx_mapping = {
    "https://docs.python.org/3": None,
}

autodoc_member_order = "bysource"
autodoc_default_options = {
    "undoc-members": True,
    "show-inheritance": True,
}


todo_include_todos = True


class PyInclude(SphinxDirective):
    has_content = True

    def run(self):
        source = "\n".join(self.content)
        output = []

        def write(*content, sep=" ", end="\n"):
            output.append(sep.join(map(str, content)) + end)

        namespace = dict(write=write)
        exec(compile(source, "<docs>", "exec"), namespace, namespace)

        output = "".join(output).splitlines()
        self.state_machine.insert_input(output, "blah")

        return []  # [nodes.literal('hello', repr(content))]


def load_entrypoint(name):
    parts = name.split(":")
    if len(parts) == 1:
        parts = name.rsplit(".", 1)
    mod_name, attrs = parts

    attrs = attrs.split(".")
    try:
        obj = __import__(mod_name, fromlist=["."])
    except ImportError as e:
        print("Error while importing.", (name, mod_name, attrs, e))
        raise

    for attr in attrs:
        obj = getattr(obj, attr)

    return obj


class EnumTable(SphinxDirective):
    required_arguments = 1
    option_spec = {
        "class": lambda x: x,
    }

    def run(self):
        cls_ep = self.options.get("class")
        cls = load_entrypoint(cls_ep) if cls_ep else None

        enum = load_entrypoint(self.arguments[0])
        properties = {}

        if cls is not None:
            for name, value in vars(cls).items():
                if isinstance(value, property):
                    try:
                        item = value._enum_item
                    except AttributeError:
                        pass
                    else:
                        if isinstance(item, enum):
                            properties[item] = name

        colwidths = [15, 15, 5, 65] if cls else [15, 5, 75]
        ncols = len(colwidths)

        table = nodes.table()

        tgroup = nodes.tgroup(cols=ncols)
        table += tgroup

        for width in colwidths:
            tgroup += nodes.colspec(colwidth=width)

        thead = nodes.thead()
        tgroup += thead

        tbody = nodes.tbody()
        tgroup += tbody

        def makerow(*texts):
            row = nodes.row()
            for text in texts:
                if text is None:
                    continue
                row += nodes.entry("", nodes.paragraph("", str(text)))
            return row

        thead += makerow(
            f"{cls.__name__} Attribute" if cls else None,
            f"{enum.__name__} Name",
            "Flag Value",
            "Meaning in FFmpeg",
        )

        seen = set()

        for name, item in enum._by_name.items():
            if name.lower() in seen:
                continue
            seen.add(name.lower())

            try:
                attr = properties[item]
            except KeyError:
                if cls:
                    continue
                attr = None

            value = f"0x{item.value:X}"
            doc = item.__doc__ or "-"
            tbody += makerow(attr, name, value, doc)

        return [table]


doxylink = {}
ffmpeg_tagfile = os.path.abspath(
    os.path.join(__file__, "..", "_build", "doxygen", "tagfile.xml")
)
if not os.path.exists(ffmpeg_tagfile):
    print("ERROR: Missing FFmpeg tagfile.")
    exit(1)
doxylink["ffmpeg"] = (ffmpeg_tagfile, "https://ffmpeg.org/doxygen/trunk/")


def doxylink_create_handler(app, file_name, url_base):
    print("Finding all names in Doxygen tagfile", file_name)

    doc = etree.parse(file_name)
    root = doc.getroot()

    parent_map = {}  # ElementTree doesn't five us access to parents.
    urls = {}

    for node in root.findall(".//name/.."):
        for child in node:
            parent_map[child] = node

        kind = node.attrib["kind"]
        if kind not in ("function", "struct", "variable"):
            continue

        name = node.find("name").text

        if kind not in ("function",):
            parent = parent_map.get(node)
            parent_name = parent.find("name") if parent else None
            if parent_name is not None:
                name = f"{parent_name.text}.{name}"

        filenode = node.find("filename")
        if filenode is not None:
            url = filenode.text
        else:
            url = "{}#{}".format(
                node.find("anchorfile").text,
                node.find("anchor").text,
            )

        urls.setdefault(kind, {})[name] = url

    def get_url(name):
        # These are all the kinds that seem to exist.
        for kind in (
            "function",
            "struct",
            "variable",  # These are struct members.
            # 'class',
            # 'define',
            # 'enumeration',
            # 'enumvalue',
            # 'file',
            # 'group',
            # 'page',
            # 'typedef',
            # 'union',
        ):
            try:
                return urls[kind][name]
            except KeyError:
                pass

    def _doxylink_handler(name, rawtext, text, lineno, inliner, options={}, content=[]):
        m = re.match(r"^(.+?)(?:<(.+?)>)?$", text)
        title, name = m.groups()
        name = name or title

        url = get_url(name)
        if not url:
            if name == "AVFrame.color_primaries":
                url = "structAVFrame.html#a59a3f830494f2ed1133103a1bc9481e7"
            elif name == "AVFrame.color_trc":
                url = "structAVFrame.html#ab09abb126e3922bc1d010cf044087939"
            else:
                print("ERROR: Could not find", name)
                exit(1)

        node = addnodes.literal_strong(title, title)
        if url:
            url = url_base + url
            node = nodes.reference("", "", node, refuri=url)

        return [node], []

    return _doxylink_handler


def setup(app):
    app.add_css_file("custom.css")

    app.add_directive("flagtable", EnumTable)
    app.add_directive("enumtable", EnumTable)
    app.add_directive("pyinclude", PyInclude)

    skip = os.environ.get("PYAV_SKIP_DOXYLINK")
    for role, (filename, url_base) in doxylink.items():
        if skip:
            app.add_role(role, lambda *args: ([], []))
        else:
            app.add_role(role, doxylink_create_handler(app, filename, url_base))
