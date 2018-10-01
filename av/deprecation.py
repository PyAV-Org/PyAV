import warnings


class AttributeRenamedWarning(UserWarning):
    pass   


class renamed_attr(object):

    """Proxy for renamed attributes (or methods) on classes.
    Getting and setting values will be redirected to the provided name,
    and warnings will be issues every time.

    """

    def __init__(self, new_name):
        self.new_name = new_name
        self._old_name = None

    def old_name(self, cls):
        if self._old_name is None:
            for k, v in vars(cls).items():
                if v is self:
                    self._old_name = k
                    break
        return self._old_name

    def __get__(self, instance, cls):
        old_name = self.old_name(cls)
        warnings.warn('%s.%s was renamed to %s' % (
            cls.__name__, old_name, self.new_name,
        ), AttributeRenamedWarning, stacklevel=2)
        return getattr(instance if instance is not None else cls, self.new_name)

    def __set__(self, instance, value):
        old_name = self.old_name(instance.__class__)
        warnings.warn('%s.%s was renamed to %s' % (
            instance.__class__.__name__, old_name, self.new_name,
        ), AttributeRenamedWarning, stacklevel=2)
        setattr(instance, self.new_name, value)

