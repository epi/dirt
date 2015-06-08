module libd;

import sh;
import unwind;

__gshared int sharedvar;

shared static this()
{
	sharedvar = 0xdead;
}

void enforce(C, T...)(C cond, lazy T msg)
{
	if (!cond)
	{
		shprint("enforcement failed: ");
		shprint(msg);
		shprint("\n");
		for (;;) {}
	}
}

extern(C) void _d_arraybounds(string file, uint line)
{
	shprint("array bounds error: ");
	shprint(file);
	shprint("@");
	shprintnum(line);
	shprint("\n");
	for (;;) {}
}

extern(C) void _d_assert(string file, uint line)
{
	shprint("assertion failed: ");
	shprint(file);
	shprint("@");
	shprintnum(line);
	shprint("\n");
	for (;;) {}
}

immutable _Unwind_Exception_Class __gdc_exception_class = ['G', 'N', 'U', 'C', 'D', '_', '_', '\0'];

extern(C)
void __gdc_terminate()
{
	for (;;) {}
}

struct d_exception_header
{
  // The object being thrown.  Like GCJ, the compiled code expects this to
  // be immediately before the generic exception header.
  enum UNWIND_PAD = (Throwable.alignof < _Unwind_Exception.alignof)
    ? _Unwind_Exception.alignof - Throwable.alignof : 0;

  // Because of a lack of __aligned__ style attribute, our object
  // and the unwind object are the first two fields.
  ubyte[cast(uint) UNWIND_PAD] pad;

  Throwable object;

  // The generic exception header.
  _Unwind_Exception unwindHeader;

  static assert(unwindHeader.offsetof - object.offsetof == object.sizeof);

  // Stack other thrown exceptions in current thread through here.
  d_exception_header *nextException;
}

__gshared d_exception_header __xh;

extern(C) private void
__gdc_exception_cleanup(_Unwind_Reason_Code code, _Unwind_Exception *exc)
{
  // If we haven't been caught by a foreign handler, then this is
  // some sort of unwind error.  In that case just die immediately.
  // _Unwind_DeleteException in the HP-UX IA64 libunwind library
  //  returns _URC_NO_REASON and not _URC_FOREIGN_EXCEPTION_CAUGHT
  // like the GCC _Unwind_DeleteException function does.
  if (code != _URC_FOREIGN_EXCEPTION_CAUGHT && code != _URC_NO_REASON)
    __gdc_terminate();

  d_exception_header *p = get_exception_header_from_ue (exc);
  *p = d_exception_header.init;
}

extern(C)
{
  int _d_isbaseof(ClassInfo, ClassInfo);
  void _d_createTrace(Object *, void *);
}

extern(C) _Unwind_Reason_Code _Unwind_RaiseException (_Unwind_Exception *);
extern(C) void
_d_throw(Object o)
{
  writefln("Exception %08x", cast(uint) cast(void*) o);
  Throwable object = cast(Throwable) o;
writefln("X");
  // Did not receive a Throwable object.
  if (object is null)
    __gdc_terminate();
writefln("Y");

  // FIXME: OOM errors will throw recursively.
  d_exception_header *xh = &__xh;
  xh.object = object;
  xh.unwindHeader.exception_class = __gdc_exception_class;
  xh.unwindHeader.exception_cleanup = &__gdc_exception_cleanup;

  // Runtime now expects us to do this first before unwinding.
//  _d_createTrace (cast(Object *) xh.object, null);

  // We're happy with setjmp/longjmp exceptions or region-based
  // exception handlers: entry points are provided here for both.
	_Unwind_RaiseException (&xh.unwindHeader);

  // If code == _URC_END_OF_STACK, then we reached top of stack without
  // finding a handler for the exception.  Since each thread is run in
  // a try/catch, this oughtn't happen.  If code is something else, we
  // encountered some sort of heinous lossage from which we could not
  // recover.  As is the way of such things, almost certainly we will have
  // crashed before now, rather than actually being able to diagnose the
  // problem.
	__gdc_terminate();
}

private d_exception_header *
get_exception_header_from_ue(_Unwind_Exception *exc)
{
  return cast(d_exception_header *)
    (cast(void *) exc - d_exception_header.unwindHeader.offsetof);
}


extern(C) int
__gdc_personality_v0(int state,
	void* ue_header,
	void* context)
{
	shprint("__gdc_personality_v0\n");
	for (;;) {}
	return 0;
}

extern(C) void *
__gdc_begin_catch(void *exc_ptr)
{
	shprint("__gdc_begin_catch\n");
	for (;;) {}
	return null;
}

extern(C)
void* _d_dynamic_cast(Object o, ClassInfo c)
{
    void* res = null;
    size_t offset = 0;
    shprint("%s", typeid(o).name);
    if (o && _d_isbaseof2(typeid(o), c, offset))
        res = cast(void*) o + offset;
    return res;
}

extern(C)
int _d_isbaseof2(ClassInfo oc, ClassInfo c, ref size_t offset)
{
    if(oc is c)
        return true;

    do
    {
	    shprintnum(offset, 10);
	    shprint("\n");
        if(oc.base is c)
            return true;
	    shprint("is not\n");

        foreach(i, iface; oc.interfaces)
        {
		    shprintnum(i, 10);
		    shprint("\n");
            if(iface.classinfo is c)
            {
                offset = iface.offset;
                return true;
            }
        }

        foreach(i, iface; oc.interfaces)
        {
		    shprintnum(i, 10);
		    shprint("\n");
            if(_d_isbaseof2(iface.classinfo, c, offset))
            {
                offset = iface.offset;
                return true;
            }
        }
	    shprint("xx not\n");

        oc = oc.base;
    }
    while(oc);
	    shprint("false\n");

    return false;
}
