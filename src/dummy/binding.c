#include <stdio.h>
#include <Python.h>
#include "libavcodec/avcodec.h"
#include "libavdevice/avdevice.h"
#include "libavformat/avformat.h"

#define MODULE_NAME "dummy.binding"

static PyObject*
test(PyObject *args)
{
    // initialise libraries
    avformat_network_init();
    avdevice_register_all();

    fprintf(stderr, "FFmpeg is OK\n");

    Py_RETURN_NONE;
}

static PyMethodDef module_methods[] = {
    {"test", (PyCFunction)test, METH_NOARGS, ""},
    {NULL}
};

static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    MODULE_NAME,                        /* m_name */
    "Dummy bindings for FFmpeg.",       /* m_doc */
    -1,                                 /* m_size */
    module_methods,                     /* m_methods */
    NULL,                               /* m_reload */
    NULL,                               /* m_traverse */
    NULL,                               /* m_clear */
    NULL,                               /* m_free */
};

PyMODINIT_FUNC
PyInit_binding(void)
{
    PyObject* m;

    m = PyModule_Create(&moduledef);
    if (m == NULL)
        return NULL;

    return m;
}
