cimport libav as lib


cdef class ContainerFormat(object):

    def __cinit__(self, bytes name):

        # We need to hold onto the original name because AVInputFormat.name
        # is actually comma-seperated, and so we need to remember which one
        # this was.
        self.name = name

        # Searches comma-seperated names.
        self.in_ = lib.av_find_input_format(name)

        while True:
            self.out = lib.av_oformat_next(self.out)
            if not self.out or self.out.name == name:
                break

        if not self.in_ and not self.out_:
            raise ValueError('no container format %r' % name)

    def __repr__(self):
        return '<av.%s %r>' % (self.__class__.__name__, self.name)

    property is_input:
        def __get__(self):
            return self.in_ != NULL

    property is_output:
        def __get__(self):
            return self.out != NULL

    property long_name:
        def __get__(self):
            return self.out.long_name if self.out else self.in_.long_name

    property extensions:
        def __get__(self):
            cdef set exts = set()
            if self.in_ and self.in_.extensions:
                exts.update(self.in_.extensions.split(','))
            if self.out and self.out.extensions:
                exts.update(self.out.extensions.split(','))
            return exts


names = set()

cdef lib.AVInputFormat *in_ = NULL
while True:
    in_ = lib.av_iformat_next(in_)
    if not in_:
        break
    names.add(in_.name)

cdef lib.AVOutputFormat *out = NULL
while True:
    out = lib.av_oformat_next(out)
    if not out:
        break
    names.add(out.name)

