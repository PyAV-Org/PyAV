import os
import re
import sys

import sphinx
from docutils import nodes
from sphinx.util.docutils import SphinxDirective

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
source_suffix = ".rst"
master_doc = "index"
project = "PyAV"
copyright = "2025, The PyAV Team"

# The version info for the project you're documenting, acts as replacement for
# |version| and |release|, also used in various other places throughout the
# built documents.

about = {}
with open("../av/about.py") as fp:
    exec(fp.read(), about)

release = about["__version__"]
version = release.split("-")[0]
exclude_patterns = ["_build"]
pygments_style = "sphinx"

# -- Options for HTML output ---------------------------------------------------

html_theme = "pyav"
html_theme_path = [os.path.abspath(os.path.join(__file__, "..", "_themes"))]

# The name of an image file (relative to this directory) to place at the top
# of the sidebar.
html_logo = "_static/logo.webp"

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

doctest_global_cleanup = "os.chdir(_cwd)"
doctest_test_doctest_blocks = ""

extlinks = {
    "ffstruct": ("https://ffmpeg.org/doxygen/trunk/struct%s.html", "struct %s"),
    "issue": ("https://github.com/PyAV-Org/PyAV/issues/%s", "#%s"),
    "pr": ("https://github.com/PyAV-Org/PyAV/pull/%s", "#%s"),
    "gh-user": ("https://github.com/%s", "@%s"),
}

intersphinx_mapping = {"python": ("https://docs.python.org/3", None)}

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
        enum_items = [
            (name, item) for name, item in vars(enum).items() if isinstance(item, enum)
        ]
        for name, item in enum_items:
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
            doc = enum.__annotations__.get(name, "---")[1:-1]
            tbody += makerow(attr, name, value, doc)

        return [table]


def ffmpeg_role(name, rawtext, text, lineno, inliner, options={}, content=[]):
    """
    Custom role for FFmpeg API links.
    Converts :ffmpeg:`AVSomething` into proper FFmpeg API documentation links.
    """

    base_url = "https://ffmpeg.org/doxygen/7.0/struct{}.html"

    try:
        struct_name, member = text.split(".")
    except Exception:
        struct_name = None

    if struct_name is None:
        url = base_url.format(text)
    else:
        fragment = {
            "AVCodecContext.thread_count": "#aa852b6227d0778b62e9cc4034ad3720c",
            "AVCodecContext.thread_type": "#a7651614f4309122981d70e06a4b42fcb",
            "AVCodecContext.skip_frame": "#af869b808363998c80adf7df6a944a5a6",
            "AVCodec.capabilities": "#af51f7ff3dac8b730f46b9713e49a2518",
            "AVCodecDescriptor.props": "#a9949288403a12812cd6e3892ac45f40f",
        }.get(text, f"#{member}")

        url = base_url.format(struct_name) + fragment

    node = nodes.reference(rawtext, text, refuri=url, **options)
    return [node], []


def setup(app):
    app.add_css_file("custom.css")
    app.add_role("ffmpeg", ffmpeg_role)
    app.add_directive("flagtable", EnumTable)
    app.add_directive("enumtable", EnumTable)
    app.add_directive("pyinclude", PyInclude)

    return {
        "version": "1.0",
        "parallel_read_safe": True,
        "parallel_write_safe": True,
    }
