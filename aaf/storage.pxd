cimport lib
from base cimport AAFObject,AAFBase

cdef class IAAFFileProxy(AAFBase):
    cdef lib.IAAFFile *ptr
    cdef object setup(self)
  
cdef class File(object):
    cdef IAAFFileProxy proxy
    cdef readonly bytes mode
    cdef object setup_new_file(self, bytes path, bytes mode=*)
    
cdef class Header(AAFObject):
    cdef lib.IAAFHeader *ptr
    
cdef class ContentStorage(AAFObject):
    cdef lib.IAAFContentStorage *ptr
