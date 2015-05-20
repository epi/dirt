module object;

import sh;

extern(C) size_t strlen(const(char)* str);

alias typeof(int.sizeof)                    size_t;
alias typeof(cast(void*)0 - cast(void*)0)   ptrdiff_t;

alias ptrdiff_t sizediff_t; //For backwards compatibility only.

alias size_t hash_t; //For backwards compatibility only.
alias bool equals_t; //For backwards compatibility only.

alias immutable(char)[]  string;
alias immutable(wchar)[] wstring;
alias immutable(dchar)[] dstring;

class Object
{
	string  toString() { return null; }
	size_t  toHash() @trusted  { return 0; }
	int     opCmp(Object o) { return 0; }
	bool    opEquals(Object o) { return false; }

	interface Monitor
	{
		void lock();
		void unlock();
	}

	static Object factory(string classname);
}

extern (C) Object _d_newclass(const ClassInfo ci)
{
	return null;
}

class TypeInfo
{
/*	override string toString() const  @safe ;
	override size_t toHash() @trusted const;
	override int opCmp(Object o);
	override bool opEquals(Object o);*/
	size_t   getHash(in void* p) @trusted nothrow const { return 0; }

//	ubyte[4] foo;
}

struct Interface
{
	TypeInfo_Class   classinfo;
	void*[]	 vtbl;
	size_t	  offset;   // offset to Interface 'this' from Object 'this'
}

bool _xopEquals(in void* ptr1, in void* ptr2) { return false; }

class TypeInfo_Const : TypeInfo
{
	TypeInfo next;
}

class TypeInfo_Array : TypeInfo
{
	TypeInfo value;
}

class TypeInfo_Pointer : TypeInfo
{
	TypeInfo m_next;
}

class TypeInfo_Class : TypeInfo
{
	@property auto info() @safe const { return this; }
	@property auto typeinfo() @safe const { return this; }

	byte[]         init;   // class static initializer
	string         name;   // class name
	void*[]        vtbl;   // virtual function pointer table
	Interface[]    interfaces;
	TypeInfo_Class base;
	void*          destructor;
	void function(Object) classInvariant;

	ubyte[24] bar;
}

class TypeInfo_Struct : TypeInfo
{
	ubyte[52] bar;
}

alias TypeInfo_Class ClassInfo;

class TypeInfo_Interface : TypeInfo
{
	ClassInfo info;
}

enum
{
	MIctorstart   = 0x1,
	MIctordone    = 0x2,
	MIstandalone  = 0x4,
	MItlsctor     = 0x8,
	MItlsdtor     = 0x10,
	MIctor        = 0x20,
	MIdtor        = 0x40,
	MIxgetMembers = 0x80,
	MIictor       = 0x100,
	MIunitTest    = 0x200,
	MIimportedModules = 0x400,
	MIlocalClasses = 0x800,
	MIname        = 0x1000,
}


struct ModuleInfo
{
	uint _flags;
	uint _index; // index into _moduleinfo_array[]

	@disable this();
	@disable this(this) const;
	@disable void opAssign(in ModuleInfo m);

const:
	private void* addrOf(int flag)
	in
	{
		assert(flag >= MItlsctor && flag <= MIname);
		assert(!(flag & (flag - 1)) && !(flag & ~(flag - 1) << 1));
	}
	body
	{
		void* p = cast(void*)&this + ModuleInfo.sizeof;

		if (flags & MItlsctor)
		{
			if (flag == MItlsctor) return p;
			p += typeof(tlsctor).sizeof;
		}
		if (flags & MItlsdtor)
		{
			if (flag == MItlsdtor) return p;
			p += typeof(tlsdtor).sizeof;
		}
		if (flags & MIctor)
		{
			if (flag == MIctor) return p;
			p += typeof(ctor).sizeof;
		}
		if (flags & MIdtor)
		{
			if (flag == MIdtor) return p;
			p += typeof(dtor).sizeof;
		}
		if (flags & MIxgetMembers)
		{
			if (flag == MIxgetMembers) return p;
			p += typeof(xgetMembers).sizeof;
		}
		if (flags & MIictor)
		{
			if (flag == MIictor) return p;
			p += typeof(ictor).sizeof;
		}
		if (flags & MIunitTest)
		{
			if (flag == MIunitTest) return p;
			p += typeof(unitTest).sizeof;
		}
			p += size_t.sizeof;
		if (flags & MIimportedModules)
		{
			if (flag == MIimportedModules) return p;
			p += size_t.sizeof + *cast(size_t*)p * typeof(importedModules[0]).sizeof;
		}
		if (flags & MIlocalClasses)
		{
			if (flag == MIlocalClasses) return p;
			p += size_t.sizeof + *cast(size_t*)p * typeof(localClasses[0]).sizeof;
		}
		if (true || flags & MIname) // always available for now
		{
			if (flag == MIname) return p;
			p += .strlen(cast(immutable char*)p);
		}
		assert(0);
	}

	@property uint index()   { return _index; }

	@property uint flags()   { return _flags; }

	@property void function() tlsctor()
	{
		return flags & MItlsctor ? *cast(typeof(return)*)addrOf(MItlsctor) : null;
	}

	@property void function() tlsdtor()
	{
		return flags & MItlsdtor ? *cast(typeof(return)*)addrOf(MItlsdtor) : null;
	}

	@property void* xgetMembers()
	{
		return flags & MIxgetMembers ? *cast(typeof(return)*)addrOf(MIxgetMembers) : null;
	}

	@property void function() ctor()
	{
		return flags & MIctor ? *cast(typeof(return)*)addrOf(MIctor) : null;
	}

	@property void function() dtor()
	{
		return flags & MIdtor ? *cast(typeof(return)*)addrOf(MIdtor) : null;
	}

	@property void function() ictor()
	{
		return flags & MIictor ? *cast(typeof(return)*)addrOf(MIictor) : null;
	}

	@property void function() unitTest()
	{
		return flags & MIunitTest ? *cast(typeof(return)*)addrOf(MIunitTest) : null;
	}

	@property immutable(ModuleInfo*)[] importedModules()
	{
		if (flags & MIimportedModules)
		{
			auto p = cast(size_t*)addrOf(MIimportedModules);
			return (cast(immutable(ModuleInfo*)*)(p + 1))[0 .. *p];
		}
		return null;
	}

	@property TypeInfo_Class[] localClasses()
	{
		if (flags & MIlocalClasses)
		{
			auto p = cast(size_t*)addrOf(MIlocalClasses);
			return (cast(TypeInfo_Class*)(p + 1))[0 .. *p];
		}
		return null;
	}

	@property string name()
	{
		if (true || flags & MIname) // always available for now
		{
			auto p = cast(immutable char*)addrOf(MIname);
			return p[0 .. .strlen(p)];
		}
		// return null;
	}
}

// This linked list is created by a compiler generated function inserted
// into the .ctor list by the compiler.
struct ModuleReference
{
	ModuleReference* next;
	private uint _mod;

	@property immutable(ModuleInfo)* mod()
	{
		return cast(immutable(ModuleInfo)*) (_mod & ~3U);
	}

	@property bool initialized()
	{
		return _mod & 1;
	}

	@property void initialized(bool i)
	{
		_mod = _mod & ~3U | (i ? 1 : 0);
	}
}

extern (C) __gshared ModuleReference* _Dmodule_ref;   // start of linked list
