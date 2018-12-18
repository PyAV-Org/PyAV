import sys

sys.path.append('/usr/local/lib/python2.7/site-packages')
from PyQt4 import QtCore, QtGui, QtOpenGL, QtMultimedia


class QtProxy(object):

	def __init__(self, *modules):
		self._modules = modules

	def __getattr__(self, base_name):
		for mod in self._modules:
			for prefix in ('Q', '', 'Qt'):
				name = prefix + base_name
				obj = getattr(mod, name, None)
				if obj is not None:
					setattr(self, base_name, obj)
					return obj
		raise AttributeError(base_name)

Q = QtProxy(QtGui, QtCore, QtCore.Qt, QtOpenGL, QtMultimedia)
