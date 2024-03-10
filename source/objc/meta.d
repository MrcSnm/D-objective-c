module objc.meta;
import std.traits;

private
{
    version(ARM) enum isARM = true;
    else version(AArch64) enum isARM = true;
    else enum isARM = false;
}

extern(C)
{
    void objc_msgSend(void* instance, SEL, ...);
    static if(!isARM) {
        void objc_msgSend_stret(void* returnObject, void* instance, SEL, ...);
        void objc_msgSend_fpret(void* instance, SEL, ...);
    }
    void objc_msgSendSuper(void* instance, SEL, ...);
    void objc_msgSendSuper_stret(void* returnObject, void* instance, SEL, ...);
    void* objc_getClass(const char* name);
    void* objc_getProtocol(const char* name);
    void* class_getSuperclass(void* Class);
    SEL sel_registerName(const char* name);
}

// private void* superclass(void* self)
// {
//     static SEL s;
//     if(s == null) s = sel_registerName("superclass");
//     alias fn = extern(C) void* function(void*, SEL);
//     return (cast(fn)&objc_msgSend)(self, s);
// }

// objc_super _objcGetSuper(void* self)
// {
//     return objc_super(self, superclass(self));
// }

struct ObjectiveC;
struct selector{string sel;}
alias SEL = void*;
struct instancetype;
struct objc_super
{
    void* self;
    void* superClass;
}

bool isAlias(T, string member)()
{
    return __traits(identifier, __traits(getMember, T, member)) != member ||
        !(__traits(isSame, T, __traits(parent, __traits(getMember, T, member))));
}
bool isAliasModule(alias T, string member)()
{
    return __traits(identifier, __traits(getMember, T, member)) != member;
}

template objcFuncT(alias fn, Class)
{
    alias objcFuncT = extern(C) ReturnType!fn function(Class self, SEL, Parameters!fn);
}

string _ObjcGetMsgSend(alias Fn, string arg, bool sliceFirst)()
{
    alias RetT = ReturnType!Fn;
    enum ident = selToIdent(__traits(getAttributes, Fn)[0].sel);
    static if(!isARM)
    {
        static if(is(RetT == struct))
        {
            enum send = "objc_msgSend_stret";
            return "ReturnType!ov structReturn;" ~
            "alias fn = extern(C) void function(void*, Class, SEL, Parameters!ov);"~
            "(cast(fn)&objc_msgSend_stret)(&structReturn, " ~arg~", "~ident~", __traits(parameters)"~(sliceFirst ? "[1..$]" : "")~");" ~
            "return structReturn;";
        }
        else
        {
            static if(__traits(isFloating, RetT))
                enum send = "objc_msgSend_fpret";
            else 
                enum send = "objc_msgSend";
            return "return (cast(objcFuncT!(ov, Class))&"~send~")("~arg~", "~ident~", __traits(parameters)"~(sliceFirst ? "[1..$]" : "")~");";
        }
    }
    else
    {
        return "return (cast(objcFuncT!(ov, Class))&objc_msgSend)("~arg~", "~ident~", __traits(parameters)"~(sliceFirst ? "[1..$]" : "")~");";
    }
}

// string _ObjcGetMsgSuperSend(alias Fn, string arg, bool sliceFirst)()
// {
//     alias RetT = ReturnType!Fn;
//     static if(is(RetT == struct))
//         enum send = "objc_msgSendSuper_stret";
//     else
//         enum send = "objc_msgSendSuper";

//     enum ident = selToIdent(__traits(getAttributes, Fn)[0].sel);
//     return "return (cast(fn)&"~send~")("~arg~", "~ident~", __traits(parameters)"~(sliceFirst ? "[1..$]" : "")~");";
// }


template GetClassSuperChain(Class)
{
    import std.meta:AliasSeq;
    static if(__traits(hasMember, Class, "SuperClass"))
        alias GetClassSuperChain = AliasSeq!(__traits(getMember, Class, "SuperClass"), GetClassSuperChain!(__traits(getMember, Class, "SuperClass")));
    else
        alias GetClassSuperChain = AliasSeq!();
}


mixin template ObjcExtend(Classes...)
{
    import std.traits:ReturnType, Parameters, hasUDA;
    import objc.meta:isAlias, selector;
    extern(D) static alias SuperClass = Classes[0];
    pragma(inline, true) extern(D) Classes[0] toSuperClass(){return cast(Classes[0])this;}

    static foreach(Class; Classes) static foreach(mem; __traits(derivedMembers, Class))
    {
        static if(!isAlias!(Class, mem) && !__traits(hasMember, typeof(this), mem))
        {
            static foreach(ov; __traits(getOverloads, Class, mem))
            {
                final @selector(__traits(getAttributes, ov)[0].sel)
                mixin((__traits(isStaticFunction, ov) ? " static" : ""), 
                (hasUDA!(ov, instancetype) ? " @instancetype typeof(this) " : " ReturnType!ov "),mem,"(Parameters!ov);");
            }
        }
    }
    alias toSuperClass this;
}

string selToIdent(string sel)
{
    char[] ret = new char[sel.length+4];
    ret[0..4] = "_SeL";
    foreach(i; 0..sel.length)
    {
        ret[i+4] = (sel[i] == ':' ? '_' : sel[i]);
    }
    return cast(string)ret;
}

enum _metaGensym(string prefix = "_") =
	'"' ~ prefix ~ `" ~ __traits(identifier, {})["__lambda".length .. $]`;


mixin template ObjcLink(Class)
{
    import std.traits;
    import objc.meta;
    mixin(" void* ",Class.stringof,"_;");
    static foreach(mem; __traits(derivedMembers, Class))
    {
        static if(!isAlias!(Class, mem))
        static foreach(ov; __traits(getOverloads, Class, mem))
        {
            static if(__traits(getLinkage, ov) == "C++")
            {
                static if(!is(typeof(mixin(selToIdent(__traits(getAttributes, ov)[0].sel)))))
                {
                    @selector(__traits(getAttributes, ov)[0].sel)
                    mixin("__gshared SEL ",selToIdent(__traits(getAttributes, ov)[0].sel),";");
                }
                static if(__traits(isStaticFunction, ov))
                {
                    pragma(mangle, ov.mangleof) extern(C)
                    mixin("auto ",mixin(_metaGensym!()), " (Parameters!ov)",
                    "{",
                    _ObjcGetMsgSend!(ov, "cast(Class)"~Class.stringof~"_", false),
                    "}");
                }
                else
                {
                    pragma(mangle, ov.mangleof) extern(C)
                    mixin("auto ",mixin(_metaGensym!()), " (Class self, Parameters!ov)",
                    "{",
                    _ObjcGetMsgSend!(ov, "self", true),
                    "}");
                }
            }
        }
    }
}

mixin template ObjcLinkModule(alias _module)
{
    import std.traits;
    static foreach(mem; __traits(allMembers, _module))
    {
        static if(is(__traits(getMember, _module, mem) == class) || is(__traits(getMember, _module, mem) == interface))
        {
            static if(!isAliasModule!(_module, mem))
                mixin ObjcLink!(__traits(getMember, _module, mem));
        }
    }

    static this()
    {
        //Initialize the module.
        static foreach(mem; __traits(allMembers, _module))
        {{
            alias modMem = __traits(getMember, _module, mem);
            static if(is(modMem == class) || is(modMem == interface))
            {
                static if(!isAliasModule!(_module, mem))
                {
                    static if(is(modMem == class) && hasUDA!(modMem, ObjectiveC))
                        mixin(mem,"_ = objc_getClass(mem);");
                    else static if(is(modMem == interface) && hasUDA!(modMem, ObjectiveC))
                        mixin(mem,"_ = objc_getProtocol(mem);");
                }
            }
        }}
    }
}

mixin template ObjcInitSelectors(alias _module)
{
    import std.traits;
    static this()
    {
        static foreach(mem; __traits(allMembers, _module))
        {{
            static if(mem.length > 4 && mem[0..4] == "_SeL")
            {
                __traits(getMember, _module, mem) = sel_registerName(__traits(getAttributes, __traits(getMember, _module, mem))[0].sel);
            }
        }}
    }
}