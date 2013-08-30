cimport lib
from base cimport AAFObject, AAFBase, AUID

cimport datadef
from essence cimport Locator, EssenceAccess

from util cimport error_check, query_interface, register_object, fraction_to_aafRational

from libcpp.vector cimport vector
from libcpp.string cimport string
from cpython cimport bool

from cython.operator cimport dereference as deref

from .iterator cimport MobSlotIter
from .component cimport Segment
from .essence cimport EssenceDescriptor
from .component cimport Segment

from wstring cimport wstring, wideToString, toWideString

cdef class MobID(object):
    
    def __repr__(self):
        return '<%s.%s of %s at 0x%x>' % (
            self.__class__.__module__,
            self.__class__.__name__,
            self.to_string(),
            id(self),
        )

    def to_string(self):
        
        f = b"urn:smpte:umid:%02x%02x%02x%02x.%02x%02x%02x%02x.%02x%02x%02x%02x." + \
             "%02x"  + \
             "%02x%02x%02x." + \
             "%02x%02x%02x%02x.%02x%02x%02x%02x.%08x.%04x%04x"
        mobID = self.mobID
        return f % (
             mobID.SMPTELabel[0], mobID.SMPTELabel[1], mobID.SMPTELabel[2],  mobID.SMPTELabel[3],
             mobID.SMPTELabel[4], mobID.SMPTELabel[5], mobID.SMPTELabel[6],  mobID.SMPTELabel[7],
             mobID.SMPTELabel[8], mobID.SMPTELabel[9], mobID.SMPTELabel[10], mobID.SMPTELabel[11],
             mobID.length,
             mobID.instanceHigh, mobID.instanceMid, mobID.instanceLow,
             mobID.material.Data4[0], mobID.material.Data4[1], mobID.material.Data4[2], mobID.material.Data4[3],
             mobID.material.Data4[4], mobID.material.Data4[5], mobID.material.Data4[6], mobID.material.Data4[7],
             mobID.material.Data1, mobID.material.Data2, mobID.material.Data3)

cdef class Mob(AAFObject):
    def __init__(self, AAFBase obj=None):
        super(Mob, self).__init__(obj)
        self.iid = lib.IID_IAAFMob
        self.auid = lib.AUID_AAFMob
        self.ptr = NULL

        if not obj:
            return

        query_interface(obj.get(), <lib.IUnknown**>&self.ptr, lib.IID_IAAFMob)

    cdef lib.IUnknown **get(self):
        return <lib.IUnknown **> &self.ptr
            
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
            
    def slots(self):
        cdef MobSlotIter slot_iter = MobSlotIter()
        error_check(self.ptr.GetSlots(&slot_iter.ptr))
        
        return slot_iter
    def add_timeline_slot(self, edit_rate, Segment seg, lib.aafSlotID_t slotID = 0, 
                            bytes slot_name = None, lib.aafPosition_t origin = 0):
        
        if not slot_name:
            slot_name = b'timeline slot %d' % slotID
        
        cdef TimelineMobSlot timeline = TimelineMobSlot()
        cdef lib.aafRational_t edit_rate_t
        
        
        fraction_to_aafRational(edit_rate, edit_rate_t)
        
        cdef wstring w_slot_name = toWideString(slot_name)
        
        error_check(self.ptr.AppendNewTimelineSlot(edit_rate_t,
                                                  seg.seg_ptr,
                                                  slotID,
                                                  w_slot_name.c_str(),
                                                  origin,
                                                  &timeline.ptr
                                                  ))
        return TimelineMobSlot(timeline)
            
    property name:
        def __get__(self):
            cdef lib.aafUInt32 sizeInBytes = 0
            error_check(self.ptr.GetNameBufLen(&sizeInBytes))
            
            cdef int sizeInChars = (sizeInBytes / sizeof(lib.aafCharacter)) + 1
            cdef vector[lib.aafCharacter] buf = vector[lib.aafCharacter](sizeInChars)
            
            error_check(self.ptr.GetName(&buf[0], sizeInChars*sizeof(lib.aafCharacter) ))
            
            cdef wstring name = wstring(&buf[0])
            return wideToString(name)
        
        def __set__(self, bytes value):
            cdef wstring name = toWideString(value)
            error_check(self.ptr.SetName(name.c_str()))
            
    property nb_slots:
        def __get__(self):
            cdef lib.aafNumSlots_t nb_slots
            error_check(self.ptr.CountSlots(&nb_slots))
            return nb_slots
    property mobID:
        """
        The unique Mob ID associated with this mob. Get Returns MobID Object
        """
        def __get__(self):
            cdef lib.aafMobID_t mobID
            error_check(self.ptr.GetMobID(&mobID))
            cdef MobID mobID_obj = MobID()
            
            mobID_obj.mobID = mobID
            return mobID_obj
            
            
cdef class MasterMob(Mob):
    def __init__(self, AAFBase obj=None):
        super(MasterMob, self).__init__(obj)
        self.iid = lib.IID_IAAFMasterMob2
        self.auid = lib.AUID_AAFMasterMob
        self.mastermob_ptr = NULL
        self.mastermob2_ptr = NULL
        if not obj:
            return

        query_interface(obj.get(), <lib.IUnknown**>&self.mastermob_ptr, lib.IID_IAAFMasterMob)
        query_interface(obj.get(), <lib.IUnknown**>&self.mastermob2_ptr, lib.IID_IAAFMasterMob2)

    cdef lib.IUnknown **get(self):
        return <lib.IUnknown **> &self.mastermob_ptr
    
    def initialize(self, bytes name):
        error_check(self.mastermob_ptr.Initialize())
        if name:
            self.name = name
    
    def create_essence(self,lib.aafSlotID_t slot_index, 
                            bytes media_kind,
                            bytes codec_name,
                            edit_rate, sample_rate, 
                            bool compress=False,
                            Locator locator=None, 
                            bytes fileformat = b"aaf"):
        
        cdef datadef.DataDef media_datadef        
        media_datadef = self.dictionary().lookup_datadef(media_kind)

        cdef lib.aafRational_t edit_rate_t
        cdef lib.aafRational_t sample_rate_t
        fraction_to_aafRational(edit_rate, edit_rate_t)
        fraction_to_aafRational(sample_rate, sample_rate_t)
        
        cdef AUID codec = datadef.CodecDefMap[codec_name.lower()]
        cdef AUID container = datadef.ContainerDefMap[fileformat.lower()]
        
        print edit_rate_t,sample_rate_t,codec,container

        cdef Locator loc
        if locator:
            loc = locator
        else:
            loc = Locator()
        
        cdef EssenceAccess access = EssenceAccess()
        
        cdef lib.aafCompressEnable_t enable = lib.kAAFCompressionEnable
        if not compress:
            enable = lib.kAAFCompressionDisable

        error_check(self.mastermob_ptr.CreateEssence( slot_index,
                                                      media_datadef.ptr,
                                                      codec.get_auid(),
                                                      edit_rate_t,
                                                      sample_rate_t,
                                                      enable,
                                                      loc.loc_ptr,
                                                      container.get_auid(),
                                                      &access.ptr
                                                      ))
        return access
        
    def __dealloc__(self):
        if self.mastermob_ptr:
            self.mastermob_ptr.Release()
        if self.mastermob2_ptr:
            self.mastermob2_ptr.Release()

cdef class CompositionMob(Mob):
    def __init__(self, AAFBase obj=None):
        super(CompositionMob, self).__init__(obj)
        self.iid = lib.IID_IAAFCompositionMob2
        self.auid = lib.AUID_AAFCompositionMob
        self.compositionmob_ptr = NULL
        self.compositionmob2_ptr = NULL
        if not obj:
            return
        
        query_interface(obj.get(), <lib.IUnknown**>&self.compositionmob_ptr, lib.IID_IAAFCompositionMob)
        query_interface(obj.get(), <lib.IUnknown**>&self.compositionmob2_ptr, lib.IID_IAAFCompositionMob2)

    cdef lib.IUnknown **get(self):
        return <lib.IUnknown **> &self.compositionmob_ptr
    
    def initialize(self, bytes name):
        cdef wstring w_name = toWideString(name)
        
        error_check(self.compositionmob_ptr.Initialize(w_name.c_str()))
            
    def __dealloc__(self):
        if self.compositionmob_ptr:
            self.compositionmob_ptr.Release()
        if self.compositionmob2_ptr:
            self.compositionmob2_ptr.Release()
        
            
cdef class SourceMob(Mob):
    def __init__(self, AAFBase obj=None):
        super(Mob, self).__init__(obj)
        self.iid = lib.IID_IAAFSourceMob
        self.auid = lib.AUID_AAFSourceMob
        self.src_ptr = NULL

        if not obj:
            return

        query_interface(obj.get(), <lib.IUnknown**>&self.src_ptr, self.iid)

    cdef lib.IUnknown **get(self):
        return <lib.IUnknown **> &self.src_ptr
            
    def __dealloc__(self):
        if self.src_ptr:
            self.src_ptr.Release()
    
    property essence_descriptor:
        def __get__(self):
            cdef EssenceDescriptor descriptor = EssenceDescriptor()
            error_check(self.src_ptr.GetEssenceDescriptor(&descriptor.essence_ptr))
            return EssenceDescriptor(descriptor)

cdef class MobSlot(AAFObject):
    def __init__(self, AAFBase obj = None):
        super(MobSlot, self).__init__(obj)
        self.iid = lib.IID_IAAFMobSlot
        self.auid = lib.AUID_AAFMobSlot
        self.slot_ptr = NULL
        if not obj:
            return
        query_interface(obj.get(), <lib.IUnknown**>&self.slot_ptr, self.iid)
    cdef lib.IUnknown **get(self):
        return <lib.IUnknown **> &self.slot_ptr
            
    def __dealloc__(self):
        if self.slot_ptr:
            self.slot_ptr.Release()
    
    def segment(self):
        cdef Segment seg = Segment()
        error_check(self.slot_ptr.GetSegment(&seg.seg_ptr))
        return Segment(seg)
    
cdef class TimelineMobSlot(MobSlot):
    def __init__(self, AAFBase obj = None):
        super(TimelineMobSlot, self).__init__(obj)
        self.iid = lib.IID_IAAFTimelineMobSlot
        self.auid = lib.AUID_AAFTimelineMobSlot
        self.ptr = NULL
        if not obj:
            return
        query_interface(obj.get(), <lib.IUnknown**>&self.ptr, self.iid)
    cdef lib.IUnknown **get(self):
        return <lib.IUnknown **> &self.ptr
            
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
            
            
register_object(Mob)           
register_object(MasterMob)
register_object(CompositionMob)
register_object(SourceMob)
register_object(MobSlot)