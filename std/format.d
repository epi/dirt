module std.format;

import std.traits;

import libd;
import sh;

alias enforceFmt = enforce;

bool isDigit(char c)
{
	return c >= '0' && c <= '9';
}

T parse(T)(ref const(char)[] str)
{
	T result = 0;
	while (str.length)
	{
		char c = str[0];
		if (!isDigit(c))
			return result;
		result *= 10;
		result += c - '0';
		str = str[1 .. $];
	}
	return result;
}

bool startsWith(in char[] str, char c)
{
	if (str.length == 0)
		return false;
	return str[0] == c;
}

private void formatGeneric(Writer, D, Char)(Writer w, const(void)* arg, ref FormatSpec!Char f)
{
	formatValue(w, *cast(D*) arg, f);
}


uint formattedWrite(Writer, Char, A...)(Writer w, in Char[] fmt, A args)
{
	alias FPfmt = void function(Writer, const(void)*, ref FormatSpec!Char) @safe pure nothrow;

	auto spec = FormatSpec!Char(fmt);

	FPfmt[A.length] funs;
	const(void)*[A.length] argsAddresses;
	if (!__ctfe)
	{
		foreach (i, Arg; A)
		{
			funs[i] = ()@trusted{ return cast(FPfmt)&formatGeneric!(Writer, Arg, Char); }();
			// We can safely cast away shared because all data is either
			// immutable or completely owned by this function.
			argsAddresses[i] = (ref arg)@trusted{ return cast(const void*) &arg; }(args[i]);

			// Reflect formatting @safe/pure ability of each arguments to this function
			if (0) formatValue(w, args[i], spec);
		}
	}

	// Are we already done with formats? Then just dump each parameter in turn
	uint currentArg = 0;
	while (spec.writeUpToNextSpec(w))
	{
		if (currentArg == funs.length && !spec.indexStart)
		{
			// leftover spec?
			enforceFmt(fmt.length == 0, "Orphan format specifier: %", spec.spec);
			break;
		}
		if (spec.width == spec.DYNAMIC)
		{
			auto width = cast(typeof(spec.width))(getNthInt(currentArg, args));
			if (width < 0)
			{
				spec.flDash = true;
				width = -width;
			}
			spec.width = width;
			++currentArg;
		}
		else if (spec.width < 0)
		{
			// means: get width as a positional parameter
			auto index = cast(uint) -spec.width;
			assert(index > 0);
			auto width = cast(typeof(spec.width))(getNthInt(index - 1, args));
			if (currentArg < index) currentArg = index;
			if (width < 0)
			{
				spec.flDash = true;
				width = -width;
			}
			spec.width = width;
		}
		if (spec.precision == spec.DYNAMIC)
		{
			auto precision = cast(typeof(spec.precision))(
				getNthInt(currentArg, args));
			if (precision >= 0) spec.precision = precision;
			// else negative precision is same as no precision
			else spec.precision = spec.UNSPECIFIED;
			++currentArg;
		}
		else if (spec.precision < 0)
		{
			// means: get precision as a positional parameter
			auto index = cast(uint) -spec.precision;
			assert(index > 0);
			auto precision = cast(typeof(spec.precision))(
				getNthInt(index- 1, args));
			if (currentArg < index) currentArg = index;
			if (precision >= 0) spec.precision = precision;
			// else negative precision is same as no precision
			else spec.precision = spec.UNSPECIFIED;
		}
		// Format!
		if (spec.indexStart > 0)
		{
			// using positional parameters!
			foreach (i; spec.indexStart - 1 .. spec.indexEnd)
			{
				if (funs.length <= i) break;
				if (__ctfe)
					formatNth(w, spec, i, args);
				else
					funs[i](w, argsAddresses[i], spec);
			}
			if (currentArg < spec.indexEnd) currentArg = spec.indexEnd;
		}
		else
		{
			if (__ctfe)
				formatNth(w, spec, currentArg, args);
			else
				funs[currentArg](w, argsAddresses[currentArg], spec);
			++currentArg;
		}
	}
	return currentArg;
}

//------------------------------------------------------------------------------
// Fix for issue 1591
private int getNthInt(A...)(uint index, A args)
{
	static if (A.length)
	{
		if (index)
		{
			return getNthInt(index - 1, args[1 .. $]);
		}
		static if (isIntegral!(typeof(args[0])))
		{
			return cast(int)(args[0]);
		}
		else
		{
			enforceFmt(false, "int expected");
			assert(0);
		}
	}
	else
	{
		enforceFmt(false, "int expected");
	}
	assert(0);
}

string to(S)(ulong a) if (is(S == string))
{
	if (a == 0)
		return "0";
	string result;
	while (a)
	{
		char c = '0' + cast(char) (a % 10);
		result = c ~ result;
		a /= 10;
	}
	return result;
}

private void formatNth(Writer, Char, A...)(Writer w, ref FormatSpec!Char f, size_t index, A args)
{
	static string gencode(size_t count)()
	{
		string result;
		foreach (n; 0 .. count)
		{
			auto num = to!string(n);
			result ~=
				"case "~num~":"~
				"	formatValue(w, args["~num~"], f);"~
				"	break;";
		}
		return result;
	}

	switch (index)
	{
		mixin(gencode!(A.length)());

		default:
			assert(0, "n = "~cast(char)(index + '0'));
	}
}

/**
 * A General handler for $(D printf) style format specifiers. Used for building more
 * specific formatting functions.
 */
struct FormatSpec(Char)
{
	int width = 0;
	int precision = UNSPECIFIED;
	enum int DYNAMIC = int.max;
	enum int UNSPECIFIED = DYNAMIC - 1;

	char spec = 's';
	ubyte indexStart;
	ubyte indexEnd;
	ubyte allFlags;

	@property bool flDash() pure nothrow const { return !!(allFlags & 1); }
	@property void flDash(bool dash) nothrow { allFlags = cast(ubyte) ((allFlags & ~1) | (dash << 0)); }

	@property bool flZero() pure nothrow const { return !!(allFlags & 2); }
	@property void flZero(bool zero) nothrow { allFlags = cast(ubyte) ((allFlags & ~2) | (zero << 1)); }

	@property bool flSpace() pure nothrow const { return !!(allFlags & 4); }
	@property void flSpace(bool space) nothrow { allFlags = cast(ubyte) ((allFlags & ~4) | (space << 2)); }

	@property bool flPlus() pure nothrow const { return !!(allFlags & 8); }
	@property void flPlus(bool plus) nothrow { allFlags = cast(ubyte) ((allFlags & ~8) | (plus << 3)); }

	@property bool flHash() pure nothrow const { return !!(allFlags & 16); }
	@property void flHash(bool space) nothrow { allFlags = cast(ubyte) ((allFlags & ~16) | (space << 4)); }

	const(Char)[] nested;
	const(Char)[] sep;
	const(Char)[] trailing;

	enum immutable(Char)[] seqBefore = "[";
	enum immutable(Char)[] seqAfter = "]";
	enum immutable(Char)[] keySeparator = ":";
	enum immutable(Char)[] seqSeparator = ", ";

	this(in char[] fmt) @safe pure
	{
		trailing = fmt;
	}

	bool writeUpToNextSpec(OutputRange)(OutputRange writer)
	{
		if (trailing.empty)
			return false;
		for (size_t i = 0; i < trailing.length; ++i)
		{
			if (trailing[i] != '%') continue;
			put(writer, trailing[0 .. i]);
			trailing = trailing[i .. $];
			enforceFmt(trailing.length >= 2, `Unterminated format specifier: "%"`);
			trailing = trailing[1 .. $];

			if (trailing[0] != '%')
			{
				// Spec found. Fill up the spec, and bailout
				fillUp();
				return true;
			}
			// Doubled! Reset and Keep going
			i = 0;
		}
		// no format spec found
		put(writer, trailing);
		trailing = null;
		return false;
	}

	private void fillUp()
	{
		allFlags = 0;
		width = 0;
		precision = UNSPECIFIED;
		nested = null;
		// Parse the spec (we assume we're past '%' already)
		for (size_t i = 0; i < trailing.length; )
		{
			switch (trailing[i])
			{
			case '(':
				// Embedded format specifier.
				auto j = i + 1;
				// Get the matching balanced paren
				for (uint innerParens;;)
				{
					enforceFmt(j + 1 < trailing.length, "Incorrect format specifier: %", trailing[i .. $]);
					if (trailing[j++] != '%')
					{
						// skip, we're waiting for %( and %)
						continue;
					}
					if (trailing[j] == '-') // for %-(
					{
						++j;	// skip
						enforceFmt(j < trailing.length, "Incorrect format specifier: %", trailing[i .. $]);
					}
					if (trailing[j] == ')')
					{
						if (innerParens-- == 0) break;
					}
					else if (trailing[j] == '|')
					{
						if (innerParens == 0) break;
					}
					else if (trailing[j] == '(')
					{
						++innerParens;
					}
				}
				if (trailing[j] == '|')
				{
					auto k = j;
					for (++j;;)
					{
						if (trailing[j++] != '%')
							continue;
						if (trailing[j] == '%')
							++j;
						else if (trailing[j] == ')')
							break;
						else
							enforce(false, "Incorrect format specifier: %", trailing[j .. $]);
					}
					nested = trailing[i + 1 .. k - 1];
					sep = trailing[k + 1 .. j - 1];
				}
				else
				{
					nested = trailing[i + 1 .. j - 1];
					sep = null; // use null (issue 12135)
				}
				//this = FormatSpec(innerTrailingSpec);
				spec = '(';
				// We practically found the format specifier
				trailing = trailing[j + 1 .. $];
				return;
			case '-': flDash = true; ++i; break;
			case '+': flPlus = true; ++i; break;
			case '#': flHash = true; ++i; break;
			case '0': flZero = true; ++i; break;
			case ' ': flSpace = true; ++i; break;
			case '*':
				if (isDigit(trailing[++i]))
				{
					// a '*' followed by digits and '$' is a
					// positional format
					trailing = trailing[1 .. $];
					width = -parse!(typeof(width))(trailing);
					i = 0;
					enforceFmt(trailing[i++] == '$',
						"$ expected");
				}
				else
				{
					// read result
					width = DYNAMIC;
				}
				break;
			case '1': .. case '9':
				auto tmp = trailing[i .. $];
				const widthOrArgIndex = parse!uint(tmp);
				enforceFmt(tmp.length, "Incorrect format specifier %", trailing[i .. $]);
				i = tmp.ptr - trailing.ptr;
				if (tmp.startsWith('$'))
				{
					// index of the form %n$
					indexEnd = indexStart = cast(ubyte) widthOrArgIndex;
					++i;
				}
				else if (tmp.startsWith(':'))
				{
					// two indexes of the form %m:n$, or one index of the form %m:$
					indexStart = cast(ubyte) widthOrArgIndex;
					tmp = tmp[1 .. $];
					if (tmp.startsWith('$'))
					{
						indexEnd = indexEnd.max;
					}
					else
					{
						indexEnd = parse!(typeof(indexEnd))(tmp);
					}
					i = tmp.ptr - trailing.ptr;
					enforceFmt(trailing[i++] == '$',
						"$ expected");
				}
				else
				{
					// width
					width = cast(int) widthOrArgIndex;
				}
				break;
			case '.':
				// Precision
				if (trailing[++i] == '*')
				{
					if (isDigit(trailing[++i]))
					{
						// a '.*' followed by digits and '$' is a
						// positional precision
						trailing = trailing[i .. $];
						i = 0;
						precision = -parse!int(trailing);
						enforceFmt(trailing[i++] == '$',
							"$ expected");
					}
					else
					{
						// read result
						precision = DYNAMIC;
					}
				}
				else if (trailing[i] == '-')
				{
					// negative precision, as good as 0
					precision = 0;
					auto tmp = trailing[i .. $];
					parse!int(tmp); // skip digits
					i = tmp.ptr - trailing.ptr;
				}
				else if (isDigit(trailing[i]))
				{
					auto tmp = trailing[i .. $];
					precision = parse!int(tmp);
					i = tmp.ptr - trailing.ptr;
				}
				else
				{
					// "." was specified, but nothing after it
					precision = 0;
				}
				break;
			default:
				// this is the format char
				spec = cast(char) trailing[i++];
				trailing = trailing[i .. $];
				return;
			} // end switch
		} // end for
		enforceFmt(false, "Incorrect format specifier: ", trailing);
	}

	void printCurFmtStr() const
	{
		auto w = SHWriter();
		auto f = FormatSpec!Char("%s"); // for stringnize

		put(w, '%');
		if (indexStart != 0)
		{
			formatValue(w, indexStart, f);
			put(w, '$');
		}
		if (flDash)  put(w, '-');
		if (flZero)  put(w, '0');
		if (flSpace) put(w, ' ');
		if (flPlus)  put(w, '+');
		if (flHash)  put(w, '#');
		if (width != 0)
			formatValue(w, width, f);
		if (precision != FormatSpec!Char.UNSPECIFIED)
		{
			put(w, '.');
			formatValue(w, precision, f);
		}
		put(w, spec);
	}
}

template hasToString(T, Char)
{
	static if(isPointer!T && !isAggregateType!T)
	{
		// X* does not have toString, even if X is aggregate type has toString.
		enum hasToString = 0;
	}
	else static if (is(typeof({ T val = void; FormatSpec!Char f; val.toString((const(char)[] s){}, f); })))
	{
		enum hasToString = 4;
	}
	else static if (is(typeof({ T val = void; val.toString((const(char)[] s){}, "%s"); })))
	{
		enum hasToString = 3;
	}
	else static if (is(typeof({ T val = void; val.toString((const(char)[] s){}); })))
	{
		enum hasToString = 2;
	}
	else static if (is(typeof({ T val = void; return val.toString(); }()) S) && isSomeString!S)
	{
		enum hasToString = 1;
	}
	else
	{
		enum hasToString = 0;
	}
}

/**
Integrals are formatted like $(D printf) does.

Params:
	w = The $(D OutputRange) to write to.
	obj = The value to write.
	f = The $(D FormatSpec) defining how to write the value.
 */
void formatValue(Writer, T, Char)(Writer w, T obj, ref FormatSpec!Char f)
if (is(IntegralTypeOf!T) && !is(T == enum) && !hasToString!(T, Char))
{
  //  import std.system : Endian;
	alias U = IntegralTypeOf!T;
	U val = obj;	// Extracting alias this may be impure/system/may-throw

/+	if (f.spec == 'r')
	{
		// raw write, skip all else and write the thing
		auto raw = (ref val)@trusted{
			return (cast(const char*) &val)[0 .. val.sizeof];
		}(val);
		if (std.system.endian == Endian.littleEndian && f.flPlus
			|| std.system.endian == Endian.bigEndian && f.flDash)
		{
			// must swap bytes
			foreach_reverse (c; raw)
				put(w, c);
		}
		else
		{
			foreach (c; raw)
				put(w, c);
		}
		return;
	}+/

	uint base =
		f.spec == 'x' || f.spec == 'X' ? 16 :
		f.spec == 'o' ? 8 :
		f.spec == 'b' ? 2 :
		f.spec == 's' || f.spec == 'd' || f.spec == 'u' ? 10 :
		0;
	enforceFmt(base > 0,
		"integral");

	// Forward on to formatIntegral to handle both U and const(U)
	// Saves duplication of code for both versions.
	static if (isSigned!U)
		formatIntegral(w, cast( long) val, f, base, Unsigned!U.max);
	else
		formatIntegral(w, cast(ulong) val, f, base, U.max);
}

///
unittest
{
	import std.array : appender;
	auto w = appender!string();
	auto spec = singleSpec("%d");
	formatValue(w, 1337, spec);

	assert(w.data == "1337");
}

private void divmod6432(ulong u, uint v, out ulong q, out uint r)
{
	uint uh = u >> 32;
	uint ul = u & 0xffff_ffff;

	if (uh == 0)
	{
		q = ul / v;
		r = ul % v;
	}
	else
	{
		q = cast(ulong) (uh / v) << 32;
		ulong r0 = u - q * v;
		if (u < 0x1_0000_0000)
		{
			r = u & 0xffff_ffff;
		}
		else
		{
			// initial bounds for ql
			uint dn = 1;
			uint up = 1;
			ulong m = v;
			while (m < r0)
			{
				up <<= 1;
				m <<= 1;
			}
			// bisect to find least significant word of quotient
			while (up - dn > 1)
			{
				uint mid = ((up - dn) >> 1) + dn;
				if (cast(ulong) mid * v > r0)
					up = mid;
				else
					dn = mid;
			}
			q |= dn;
			r = cast(uint) (u - q * v);
		}
	}
}
private ulong div6432(ulong u, uint v)
{
	ulong q;
	uint r;
	divmod6432(u, v, q, r);
	return q;
}

//static assert(div6432(0xbadc0ffee0ddf00d, 0xdeadc0de) == 0xbadc0ffee0ddf00d / 0xdeadc0de);
static assert(div6432(0xee0ddf00d, 0xdeadc0de) == 0xee0ddf00d / 0xdeadc0de);


private void formatIntegral(Writer, T, Char)(Writer w, const(T) val, ref FormatSpec!Char f, uint base, ulong mask)
{
	FormatSpec!Char fs = f; // fs is copy for change its values.
	T arg = val;

	bool negative = (base == 10 && arg < 0);
	if (negative)
	{
		arg = -arg;
	}

	// All unsigned integral types should fit in ulong.
	formatUnsigned(w, (cast(ulong) arg) & mask, fs, base, negative);
}

private void formatUnsigned(Writer, Char)(Writer w, ulong arg, ref FormatSpec!Char fs, uint base, bool negative)
{
	if (fs.precision == fs.UNSPECIFIED)
	{
		// default precision for integrals is 1
		fs.precision = 1;
	}
	else
	{
		// if a precision is specified, the '0' flag is ignored.
		fs.flZero = false;
	}

	char leftPad = void;
	if (!fs.flDash && !fs.flZero)
		leftPad = ' ';
	else if (!fs.flDash && fs.flZero)
		leftPad = '0';
	else
		leftPad = 0;

	// figure out sign and continue in unsigned mode
	char forcedPrefix = void;
	if (fs.flPlus) forcedPrefix = '+';
	else if (fs.flSpace) forcedPrefix = ' ';
	else forcedPrefix = 0;
	if (base != 10)
	{
		// non-10 bases are always unsigned
		forcedPrefix = 0;
	}
	else if (negative)
	{
		// argument is signed
		forcedPrefix = '-';
	}
	// fill the digits
	char[64] buffer; // 64 bits in base 2 at most
	char[] digits;
	{
		uint i = buffer.length;
		auto n = arg;
		do
		{
			--i;
			ulong div;
			uint rem;
			divmod6432(n, base, div, rem);
			buffer[i] = cast(char) rem;
			n = div;
			if (buffer[i] < 10) buffer[i] += '0';
			else buffer[i] += (fs.spec == 'x' ? 'a' : 'A') - 10;
		} while (n);
		digits = buffer[i .. $]; // got the digits without the sign
	}
	// adjust precision to print a '0' for octal if alternate format is on
	if (base == 8 && fs.flHash
		&& (fs.precision <= digits.length)) // too low precision
	{
		//fs.precision = digits.length + (arg != 0);
		forcedPrefix = '0';
	}
	// write left pad; write sign; write 0x or 0X; write digits;
	//   write right pad
	// Writing left pad
	ptrdiff_t spacesToPrint =
		fs.width // start with the minimum width
		- digits.length  // take away digits to print
		- (forcedPrefix != 0) // take away the sign if any
		- (base == 16 && fs.flHash && arg ? 2 : 0); // 0x or 0X
	const ptrdiff_t delta = fs.precision - digits.length;
	if (delta > 0) spacesToPrint -= delta;
	if (spacesToPrint > 0) // need to do some padding
	{
		if (leftPad == '0')
		{
			// pad with zeros

			fs.precision =
				cast(typeof(fs.precision)) (spacesToPrint + digits.length);
				//to!(typeof(fs.precision))(spacesToPrint + digits.length);
		}
		else if (leftPad) foreach (i ; 0 .. spacesToPrint) put(w, ' ');
	}
	// write sign
	if (forcedPrefix) put(w, forcedPrefix);
	// write 0x or 0X
	if (base == 16 && fs.flHash && arg) {
		// @@@ overcome bug in dmd;
		//w.write(fs.spec == 'x' ? "0x" : "0X"); //crashes the compiler
		put(w, '0');
		put(w, fs.spec == 'x' ? 'x' : 'X'); // x or X
	}
	// write the digits
	if (arg || fs.precision)
	{
		ptrdiff_t zerosToPrint = fs.precision - digits.length;
		foreach (i ; 0 .. zerosToPrint) put(w, '0');
		put(w, digits);
	}
	// write the spaces to the right if left-align
	if (!leftPad) foreach (i ; 0 .. spacesToPrint) put(w, ' ');
}
