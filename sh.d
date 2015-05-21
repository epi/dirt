module sh;

import std.format;

extern(C) void shcmd(uint command, void* message)
{
	asm
	{
		"mov r0, %[cmd];
		 mov r1, %[msg];
		 bkpt #0xAB"
		:
		: [cmd] "r" command, [msg] "r" message
		: "r0", "r1", "memory";
	};
}

extern(C) void shexit()
{
	shcmd(0x18, cast(void*) 0x20026);
}

void shprint(const(char)* txt)
{
	shcmd(0x04, cast(void*) txt);
}

void shprint(in char[] a)
{
	uint[3] message = [
		2, // stderr
		cast(uint) a.ptr,
		cast(uint) a.length
	];

	shcmd(0x05, cast(void*) message.ptr);
}

void shprint(string a)
{
	uint[3] message = [
		2, // stderr
		cast(uint) a.ptr,
		cast(uint) a.length
	];

	shcmd(0x05, cast(void*) message.ptr);
}

void shprintnum(uint x, uint base = 10)
{
	char[33] buf = void;
	uint offs = 32;
	buf[offs] = '\0';
	while (x)
	{
		--offs;
		char c = cast(char) ('0' + x % base);
		if (c > '9')
			c += 'A' - ':';
		buf[offs] = c;
		x /= base;
	}
	if (offs == 32)
		buf[--offs] = '0';
	shprint(buf.ptr + offs);
}

void shprint(T...)(T args)
{
	static if (args.length)
		{}
	else
	{
		shprint(args[0]);
		shprint(args[1 .. $]);
	}
}

void writef(T...)(T args)
{
	formattedWrite(SHWriter(), args);
}

void writefln(T...)(T args)
{
	writef(args);
	shprint("\n");
}

struct SHWriter
{
}

void put(SHWriter w, char c)
{
	shprint((&c)[0 .. 1]);
}

void put(SHWriter w, const(char)[] s)
{
	shprint(s);
}
