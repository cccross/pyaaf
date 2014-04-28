
cimport lib

from .base cimport AAFBase, AAFObject
from .define cimport DefObject, ClassDef, TypeDef, DataDef, ContainerDef, OperationDef, ParameterDef, InterpolationDef, TypeDefMap, ContainerDefMap, DataDefMap, ExtEnumDefMap, InterpolationDefMap
from .util cimport error_check, query_interface, register_object, lookup_object, AUID
from .iterator cimport CodecDefIter, ClassDefIter, TypeDefIter, PluginDefIter, KLVDataDefIter, LoadedPluginIter
from wstring cimport wstring,toWideString

import traceback

cdef class Dictionary(AAFObject):
    def __cinit__(self):
        self.iid = lib.IID_IAAFDictionary
        self.auid = lib.AUID_AAFDictionary
        self.ptr = NULL
        self.ptr2 = NULL
        self.create = CreateInstance(self)
        
    cdef lib.IUnknown **get_ptr(self):
        return <lib.IUnknown **> &self.ptr
    
    cdef query_interface(self, AAFBase obj = None):
        if obj is None:
            obj = self
        else:
            query_interface(obj.get_ptr(), <lib.IUnknown **> &self.ptr, lib.IID_IAAFDictionary)
        
        if not self.ptr2:
            query_interface(obj.get_ptr(), <lib.IUnknown **> &self.ptr2, lib.IID_IAAFDictionary2)
            
        AAFObject.query_interface(self, obj)
    
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
        
        if self.ptr2:
            self.ptr2.Release()
            
    cdef create_instance(self, AAFObject obj):
        error_check(self.ptr.CreateInstance(obj.auid, obj.iid, obj.get_ptr()))
        obj.query_interface()
        obj.root = self.root
        
    cdef create_meta_instance(self, TypeDef obj, lib.aafUID_t auid):
        error_check(self.ptr.CreateMetaInstance(auid, obj.iid, obj.get_ptr()))
        obj.query_interface()
        obj.root = self.root
        
    def register_def(self, AAFBase def_obj not None):
        cdef OperationDef op_def
        cdef ParameterDef param_def
        cdef InterpolationDef interp_def
        cdef TypeDef typedef
        
        if isinstance(def_obj, TypeDef):
            typedef = def_obj
            error_check(self.ptr.RegisterTypeDef(typedef.typedef_ptr))
        elif isinstance(def_obj, OperationDef):
            op_def = def_obj
            error_check(self.ptr.RegisterOperationDef(op_def.ptr))
        elif isinstance(def_obj, ParameterDef):
            param_def = def_obj
            error_check(self.ptr.RegisterParameterDef(param_def.ptr))
        elif isinstance(def_obj, InterpolationDef):
            interp_def = def_obj
            error_check(self.ptr.RegisterInterpolationDef(interp_def.ptr))
        else:
            raise NotImplementedError("register_def not implemented for %s"  % str(type(def_obj)))

        
    def lookup_datadef(self, bytes name):
        cdef AUID auid = DataDefMap[name.lower().replace("datadef_", "")]
        cdef DataDef definition =  DataDef.__new__(DataDef)
        error_check(self.ptr.LookupDataDef(auid.get_auid(), &definition.ptr ))
        definition.query_interface()
        definition.root = self.root
        return definition
    
    def lookup_typedef(self, bytes name not None):
        for typedef in self.typedefs():
            if typedef.name == name:
                return typedef
        
        cdef AUID auid = TypeDefMap[name.lower()]
        cdef TypeDef definition = TypeDef.__new__(TypeDef)
        error_check(self.ptr.LookupTypeDef(auid.get_auid(), &definition.typedef_ptr))
        definition.query_interface()
        definition.root = self.root
        return definition.resolve()
    
    def lookup_containerdef(self, bytes name):
        cdef AUID auid = ContainerDefMap[name.lower()]
        cdef ContainerDef definition = ContainerDef.__new__(ContainerDef)
        error_check(self.ptr.LookupContainerDef(auid.get_auid(), &definition.ptr ))
        definition.query_interface()
        definition.root = self.root
        return definition
    
    def lookup_classdef(self, AUID auid):        
        cdef ClassDef classdef = ClassDef.__new__(ClassDef)
        
        error_check(self.ptr.LookupClassDef(auid.get_auid(), &classdef.ptr))
        
        classdef.query_interface()
        classdef.root = self.root
        return classdef

    def lookup_interpolatordef(self, bytes name):
        cdef PluginManager manager = PluginManager()
        
        cdef AUID auid = InterpolationDefMap[name.lower()]
        
        #cdef InterpolationDef definition = InterpolationDef.__new__(InterpolationDef)
        cdef DefObject definition = DefObject.__new__(DefObject)
        error_check(manager.ptr.CreatePluginDefinition(auid.get_auid(), self.ptr, &definition.defobject_ptr))
        return definition.resolve()

    def classdefs(self):
        cdef ClassDefIter def_iter = ClassDefIter.__new__(ClassDefIter)
        error_check(self.ptr.GetClassDefs(&def_iter.ptr))
        def_iter.root = self.root
        return def_iter

    def codecdefs(self):
        cdef CodecDefIter def_iter = CodecDefIter.__new__(CodecDefIter)
        error_check(self.ptr.GetCodecDefs(&def_iter.ptr))
        def_iter.root = self.root
        return def_iter
    
    def typedefs(self):
        cdef TypeDefIter def_iter = TypeDefIter.__new__(TypeDefIter)
        error_check(self.ptr.GetTypeDefs(&def_iter.ptr))
        def_iter.root = self.root
        return def_iter
    
    def plugindefs(self):
        cdef PluginDefIter def_iter = PluginDefIter.__new__(PluginDefIter)
        error_check(self.ptr.GetPluginDefs(&def_iter.ptr))
        def_iter.root = self.root
        return def_iter
     
    def klvdatadefs(self):
        cdef KLVDataDefIter def_iter = KLVDataDefIter.__new__(KLVDataDefIter)
        error_check(self.ptr2.GetKLVDataDefs(&def_iter.ptr))
        def_iter.root = self.root
        return def_iter
     
    def operationdefs(self):
        prop = self.get('OperationDefinitions', None)
        if prop:
            return prop.value
        return []
    
    def parameterdefs(self):
        prop = self.get('ParameterDefinitions', [])
        if prop:
            return prop.value
        return []

    def datadefs(self):
        prop = self.get('DataDefinitions', [])
        if prop:
            return prop.value
        return []
    
    def containerdefs(self):
        prop = self.get('ContainerDefinitions', [])
        if prop:
            return prop.value
        return []
    
    def interpolationdefs(self):
        prop = self.get('InterpolationDefinitions', [])
        if prop:
            return prop.value
        return []
                
    def taggedvaluedefs(self):
        prop = self.get('TaggedValueDefinitions', [])
        if prop:
            return prop.value
        return []
        
cdef class PluginManager(object):
    def __init__(self):
        error_check(lib.AAFGetPluginManager(&self.ptr))

    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
            
    def loaded_plugins(self, bytes category):
        """
        categories are:
            -codec
            -effect
            -interpolation
        """

        cdef LoadedPluginIter plugin_iter = LoadedPluginIter.__new__(LoadedPluginIter)
        cdef AUID cat = ExtEnumDefMap["plugincategory_%s" % category.lower()]
        error_check(self.ptr.EnumLoadedPlugins(cat.get_auid(), &plugin_iter.ptr))
        
        return plugin_iter

            
cdef class CreateInstance(object):

    def __init__(self, Dictionary dictionary):
        self.class_name = None
        self.dictionary = dictionary
        
    def __getattr__(self, name):
        self.class_name = name
        
        return self.create_instance
    
    def from_name(self, bytes name, *args, **kwargs):
        
        obj_type = lookup_object(name)
        return obj_type(self.dictionary.root, *args, **kwargs)

        
    def create_instance(self, *args, **kwargs):
        
        return self.from_name( self.class_name, *args, **kwargs)
    
register_object(Dictionary)
