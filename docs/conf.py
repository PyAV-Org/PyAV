import os
import re
import sys

import sphinx
from docutils import nodes
from sphinx.util.docutils import SphinxDirective

sys.path.insert(0, os.path.abspath(".."))


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
    "sphinx_copybutton",  # Add copy button to code blocks
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

html_theme_options = {
    "sidebarwidth": "250px",
}


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
        fragment = {
            "avformat_seek_file": "group__lavf__decoding.html#ga3b40fc8d2fda6992ae6ea2567d71ba30",
            "av_find_best_stream": "avformat_8c.html#a8d4609a8f685ad894c1503ffd1b610b4",
            "av_frame_make_writable": "group__lavu__frame.html#gadd5417c06f5a6b419b0dbd8f0ff363fd",
            "avformat_write_header": "group__lavf__encoding.html#ga18b7b10bb5b94c4842de18166bc677cb",
            "av_guess_frame_rate": "group__lavf__misc.html#ga698e6aa73caa9616851092e2be15875d",
            "av_guess_sample_aspect_ratio": "group__lavf__misc.html#gafa6fbfe5c1bf6792fd6e33475b6056bd",
        }.get(text, f"struct{text}.html")
        url = "https://ffmpeg.org/doxygen/7.0/" + fragment
    else:
        fragment = {
            "AVCodecContext.thread_count": "#aa852b6227d0778b62e9cc4034ad3720c",
            "AVCodecContext.thread_type": "#a7651614f4309122981d70e06a4b42fcb",
            "AVCodecContext.skip_frame": "#af869b808363998c80adf7df6a944a5a6",
            "AVCodecContext.qmin": "#a3f63bc9141e25bf7f1cda0cef7cd4a60",
            "AVCodecContext.qmax": "#ab015db3b7fcd227193a7c17283914187",
            "AVCodec.capabilities": "#af51f7ff3dac8b730f46b9713e49a2518",
            "AVCodecDescriptor.props": "#a9949288403a12812cd6e3892ac45f40f",
            "AVCodecContext.bits_per_coded_sample": "#a3866500f51fabfa90faeae894c6e955c",
            "AVFrame.color_range": "#a853afbad220bbc58549b4860732a3aa5",
            "AVFrame.color_primaries": "#a59a3f830494f2ed1133103a1bc9481e7",
            "AVFrame.color_trc": "#ab09abb126e3922bc1d010cf044087939",
            "AVFrame.colorspace": "#a9262c231f1f64869439b4fe587fe1710",
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
