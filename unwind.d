module unwind;

alias _Unwind_Reason_Code = uint;
enum : _Unwind_Reason_Code
{
	_URC_NO_REASON = 0,
	_URC_FOREIGN_EXCEPTION_CAUGHT = 1,
	_URC_FATAL_PHASE2_ERROR = 2,
	_URC_FATAL_PHASE1_ERROR = 3,
	_URC_NORMAL_STOP = 4,
	_URC_END_OF_STACK = 5,
	_URC_HANDLER_FOUND = 6,
	_URC_INSTALL_CONTEXT = 7,
	_URC_CONTINUE_UNWIND = 8
}

alias _Unwind_Ptr = uint;
alias _Unwind_Word = uint;

alias _Unwind_Exception_Class = ubyte[8];
alias _Unwind_Exception_Cleanup_Fn = extern(C) void function(_Unwind_Reason_Code, _Unwind_Exception*);

struct _Unwind_Exception
{
	_Unwind_Exception_Class exception_class;
	_Unwind_Exception_Cleanup_Fn exception_cleanup;
	_Unwind_Word w1;
	_Unwind_Word w2;
}

enum
{
	_UA_SEARCH_PHASE	= 1,
	_UA_END_OF_STACK	= 16,
	_UA_CLEANUP_PHASE	= 2,
	_UA_HANDLER_FRAME	= 4,
	_UA_FORCE_UNWIND	= 8,
}
