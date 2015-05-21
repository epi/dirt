module libd;

import sh;

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
