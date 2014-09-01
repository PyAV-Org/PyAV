'''Mikes wrapper for the visualizer???'''
from contextlib import contextmanager

from OpenGL.GLUT import *
from OpenGL.GLU import *
from OpenGL.GL import *
import OpenGL


__all__ = '''
    gl
    glu
    glut
'''.strip().split()


class ModuleProxy(object):
    
    def __init__(self, name, module):
        self.name = name
        self.module = module
    
    def __getattr__(self, name):
        if name.isupper():
            return getattr(self.module, self.name.upper() + '_' + name)
        else:
            # convert to camel case
            name = name.split('_')
            name = [x[0].upper() + x[1:] for x in name]
            name = ''.join(name)
            return getattr(self.module, self.name + name)


class GLProxy(ModuleProxy):
    
    @contextmanager
    def matrix(self):
        self.module.glPushMatrix()
        try:
            yield
        finally:
            self.module.glPopMatrix()
    
    @contextmanager
    def attrib(self, *args):
        mask = 0
        for arg in args:
            if isinstance(arg, basestring):
                arg = getattr(self.module, 'GL_%s_BIT' % arg.upper())
            mask |= arg
        self.module.glPushAttrib(mask)
        try:
            yield
        finally:
            self.module.glPopAttrib()
    
    def enable(self, *args, **kwargs):
        self._enable(True, args, kwargs)
        return self._apply_on_exit(self._enable, False, args, kwargs)
    
    def disable(self, *args, **kwargs):
        self._enable(False, args, kwargs)
        return self._apply_on_exit(self._enable, True, args, kwargs)
    
    def _enable(self, enable, args, kwargs):
        todo = []
        for arg in args:
            if isinstance(arg, basestring):
                arg = getattr(self.module, 'GL_%s' % arg.upper())
            todo.append((arg, enable))
        for key, value in kwargs.iteritems():
            flag = getattr(self.module, 'GL_%s' % key.upper())
            value = value if enable else not value
            todo.append((flag, value))
        for flag, value in todo:
            if value:
                self.module.glEnable(flag)
            else:
                self.module.glDisable(flag)
        
    def begin(self, arg):
        if isinstance(arg, basestring):
            arg = getattr(self.module, 'GL_%s' % arg.upper())
        self.module.glBegin(arg)
        return self._apply_on_exit(self.module.glEnd)
    
    @contextmanager
    def _apply_on_exit(self, func, *args, **kwargs):
        try:
            yield
        finally:
            func(*args, **kwargs)
        

gl = GLProxy('gl', OpenGL.GL)
glu = ModuleProxy('glu', OpenGL.GLU)
glut = ModuleProxy('glut', OpenGL.GLUT)
