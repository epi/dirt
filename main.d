/*

r3 := 0x20000024
r2 := 0x20000000
r1 := *r3
*r3 := r2
*r2 := r1

r1 = _Dmodule_ref
_Dmodule_ref = &__mod_ref.3657
__mod_ref.3657.next = r1


*/

import sh;
import libd;

__gshared extern(C) int x;
__gshared extern(C) int y;

shared static this()
{
	x = libd.sharedvar;
}

static this()
{
	y = 0xf4ce;
}

class Foo
{
	static __gshared int z;

	shared static this()
	{
		z = 0xbeef;
	}

	string name() { return "foo"; }
}

class Bar : Foo
{
	override string name() { return "bar"; }
}

void main()
{
	shprint("Hello, world!\n");
	shprintnum(0xdeadbeef, 16);
	shprint("\n");
}

