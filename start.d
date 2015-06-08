import sh;

extern(C) extern __gshared immutable(ubyte) _etext;
extern(C) extern __gshared ubyte _data;
extern(C) extern __gshared ubyte _edata;
extern(C) extern __gshared ubyte _bstart;
extern(C) extern __gshared ubyte _bend;

alias InitFunc = void function();

__gshared extern(C) extern InitFunc __init_array_start;
__gshared extern(C) extern InitFunc __init_array_end;

extern(C) int _Dmain();

ModuleReference* findModuleReference(immutable(ModuleInfo)* mod)
{
	ModuleReference* mr;
	for (mr = _Dmodule_ref; mr !is null; mr = mr.next)
	{
		if (mr.mod is mod)
			return mr;
	}
	return null;
}

void initializeMod(immutable(ModuleInfo)* mod)
{
	ModuleReference *mr = findModuleReference(mod);
	if (mr.initialized)
		return;
//	foreach (m; mod.importedModules)
//		initializeMod(m);
//	shprint(" ");
//	shprint(mod.name);
	mr.initialized = true;
}

private extern(C) int _d_run_main(int argc, char **argv, void* mainFunc)
{
	shprint("Copying data from Flash to SRAM: ");
	shprintnum(cast(uint) &_data, 16);
	shprint("..");
	shprintnum(cast(uint) &_edata, 16);
	shprint(" <- ");
	shprintnum(cast(uint) &_etext, 16);
	shprint("\n");

	ubyte* dest = &_data;
	immutable(ubyte)* src = &_etext;
	while (dest != &_edata)
		*dest++ = *src++;

	shprint("Clearing bss: ");
	shprintnum(cast(uint) &_bstart, 16);
	shprint("..");
	shprintnum(cast(uint) &_bend, 16);
	shprint("\n");
	dest = &_bstart;
	while (dest != &_bend)
		*dest++ = 0;

	shprint("Calling global constructors:");
	for (InitFunc *p = &__init_array_start; p != &__init_array_end; ++p)
	{
		shprint(" @");
		shprintnum(cast(uint) *p, 16);
		(*p)();
	}
	shprint(".\n");

	shprint("Initializing modules:");
	ModuleReference* mr;
	for (mr = _Dmodule_ref; mr !is null; mr = mr.next)
		initializeMod(mr.mod);
	shprint(".\nEntering main...\n");
	_Dmain();
	shprint("Terminating...\n");
	return 0;
}

private extern(C) void resetISR()
{
	_d_run_main(0, null, null);
	shexit();
}
