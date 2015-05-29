module std.traits;

import std.typetuple;

bool empty(const(char)[] x) { return x.length == 0; }

alias IntegralTypeList      = TypeTuple!(byte, ubyte, short, ushort, int, uint, long, ulong);

enum bool isIntegral(T) = is(IntegralTypeOf!T) && !isAggregateType!T;

enum bool isPointer(T) = is(T == U*, U) && !isAggregateType!T;

enum bool isAggregateType(T) = is(T == struct) || is(T == union) ||
                               is(T == class) || is(T == interface);

enum bool isSigned(T) = is(SignedTypeOf!T) && !isAggregateType!T;

template SignedTypeOf(T)
{
    static if (is(IntegralTypeOf!T X) &&
               staticIndexOf!(Unqual!X, SignedIntTypeList) >= 0)
        alias SignedTypeOf = X;
    else static if (is(FloatingPointTypeOf!T X))
        alias SignedTypeOf = X;
    else
        static assert(0, T.stringof~" is not an signed type.");
}

template BooleanTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = BooleanTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (is(Unqual!X == bool))
    {
        alias BooleanTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not boolean type");
}

/*
Always returns the Dynamic Array version.
 */
template StringTypeOf(T)
{
    static if (is(T == typeof(null)))
    {
        // It is impossible to determine exact string type from typeof(null) -
        // it means that StringTypeOf!(typeof(null)) is undefined.
        // Then this behavior is convenient for template constraint.
        static assert(0, T.stringof~" is not a string type");
    }
    else static if (is(T : const char[]) || is(T : const wchar[]) || is(T : const dchar[]))
    {
        static if (is(T : U[], U))
            alias StringTypeOf = U[];
        else
            static assert(0);
    }
    else
        static assert(0, T.stringof~" is not a string type");
}

template Unqual(T)
{
    version (none) // Error: recursive alias declaration @@@BUG1308@@@
    {
             static if (is(T U ==     const U)) alias Unqual = Unqual!U;
        else static if (is(T U == immutable U)) alias Unqual = Unqual!U;
        else static if (is(T U ==     inout U)) alias Unqual = Unqual!U;
        else static if (is(T U ==    shared U)) alias Unqual = Unqual!U;
        else                                    alias Unqual =        T;
    }
    else // workaround
    {
             static if (is(T U ==          immutable U)) alias Unqual = U;
        else static if (is(T U == shared inout const U)) alias Unqual = U;
        else static if (is(T U == shared inout       U)) alias Unqual = U;
        else static if (is(T U == shared       const U)) alias Unqual = U;
        else static if (is(T U == shared             U)) alias Unqual = U;
        else static if (is(T U ==        inout const U)) alias Unqual = U;
        else static if (is(T U ==        inout       U)) alias Unqual = U;
        else static if (is(T U ==              const U)) alias Unqual = U;
        else                                             alias Unqual = T;
    }
}

private template AliasThisTypeOf(T) if (isAggregateType!T)
{
    alias members = TypeTuple!(__traits(getAliasThis, T));

    static if (members.length == 1)
    {
        alias AliasThisTypeOf = typeof(__traits(getMember, T.init, members[0]));
    }
    else
        static assert(0, T.stringof~" does not have alias this type");
}

template IntegralTypeOf(T)
{
    static if (is(AliasThisTypeOf!T AT) && !is(AT[] == AT))
        alias X = IntegralTypeOf!AT;
    else
        alias X = OriginalType!T;

    static if (staticIndexOf!(Unqual!X, IntegralTypeList) >= 0)
    {
        alias IntegralTypeOf = X;
    }
    else
        static assert(0, T.stringof~" is not an integral type");
}

template OriginalType(T)
{
    template Impl(T)
    {
        static if (is(T U == enum)) alias Impl = OriginalType!U;
        else                        alias Impl =              T;
    }

    alias OriginalType = ModifyTypePreservingSTC!(Impl, T);
}

package template ModifyTypePreservingSTC(alias Modifier, T)
{
         static if (is(T U ==          immutable U)) alias ModifyTypePreservingSTC =          immutable Modifier!U;
    else static if (is(T U == shared inout const U)) alias ModifyTypePreservingSTC = shared inout const Modifier!U;
    else static if (is(T U == shared inout       U)) alias ModifyTypePreservingSTC = shared inout       Modifier!U;
    else static if (is(T U == shared       const U)) alias ModifyTypePreservingSTC = shared       const Modifier!U;
    else static if (is(T U == shared             U)) alias ModifyTypePreservingSTC = shared             Modifier!U;
    else static if (is(T U ==        inout const U)) alias ModifyTypePreservingSTC =        inout const Modifier!U;
    else static if (is(T U ==        inout       U)) alias ModifyTypePreservingSTC =              inout Modifier!U;
    else static if (is(T U ==              const U)) alias ModifyTypePreservingSTC =              const Modifier!U;
    else                                             alias ModifyTypePreservingSTC =                    Modifier!T;
}

