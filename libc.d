module libc;

extern(C) size_t strlen(const(char)* str) pure nothrow
{
	size_t result;
	while (*str++)
		++result;
	return result;
}

