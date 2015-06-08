module libc;

extern(C) size_t strlen(const(char)* str) pure nothrow
{
	size_t result;
	while (*str++)
		++result;
	return result;
}

extern(C) void* memset(void* ptr, int value, size_t num)
{
	for (size_t i = 0; i < num; ++i)
	{
		(cast(ubyte*)ptr)[i] = cast(ubyte) value;
	}
	return ptr;
}

extern(C) void* memcpy(void* destination, const(void)* source, size_t num)
{
	for (size_t i = 0; i < num; ++i)
	{
		(cast(ubyte*) destination)[i] = (cast(const(ubyte)*) source)[i];
	}
	return destination;
}

extern(C) void abort()
{
	for (;;) {}
}
