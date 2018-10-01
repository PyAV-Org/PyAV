import warnings


class AttributeRenamedWarning(DeprecationWarning):
    pass   


# DeprecationWarning is not printed by default (unless in __main__). We
# really want these to be seen, but also to use the "correct" base classes.
# So we're putting a filter in place to show our warnings. The users can
# turn them back off if they want.
warnings.filterwarnings('default', '', AttributeRenamedWarning)


class renamed_attr(object):

    """Proxy for renamed attributes (or methods) on classes.
    Getting and setting values will be redirected to the provided name,
    and warnings will be issues every time.

    E.g.::

        >>> class Example(object):
        ... 
        ...     new_value = 'something'
        ...     old_value = renamed_attr('new_value')
        ...     
        ...     def new_func(self, a, b):
        ...         return a + b
        ...         
        ...     old_func = renamed_attr('new_func')

        >>> e = Example()
        
        >>> e.old_value = 'else' # doctest: +ELLIPSIS
        /... AttributeRenamedWarning: Example.old_value is deprecated; please use Example.new_value. ...

        >>> e.old_func(1, 2) # doctest: +ELLIPSIS
        /... AttributeRenamedWarning: Example.old_func is deprecated; please use Example.new_func. ...
        3
    
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
        warnings.warn('{0}.{1} is deprecated; please use {0}.{2}.'.format(
            cls.__name__, old_name, self.new_name,
        ), AttributeRenamedWarning, stacklevel=2)
        return getattr(instance if instance is not None else cls, self.new_name)

    def __set__(self, instance, value):
        old_name = self.old_name(instance.__class__)
        warnings.warn('{0}.{1} is deprecated; please use {0}.{2}.'.format(
            instance.__class__.__name__, old_name, self.new_name,
        ), AttributeRenamedWarning, stacklevel=2)
        setattr(instance, self.new_name, value)

