module objc.runtime;
public import objc.meta : selector, ObjectiveC, ObjcExtend, instancetype;
public import objc.clang_block;


private bool isValidObjectiveCNumber(T)()
{
    return  is(T == BOOL) || is(T == byte) || is(T == ubyte)  ||
            is(T == short) || is(T == ushort) ||
            is(T == int) || is(T == uint) ||
            is(T == long) || is(T == ulong);
}

////ns Helper Section////
/**
*   .ns can be used as a postfix to convert almost any type to its Objective-C representation.
*   Currently it supports:
    - string
    - numbers
    - associative arrays
    - identity (used on any object that extends NSObject will return itself)
*/

NSString ns(string istr) nothrow @nogc {
    import core.stdc.stdlib : malloc, free;

    char* str = cast(char*)malloc(istr.length+1);
    str[0..istr.length] = istr[0..$];
    str[istr.length] = '\0';

    NSString out_ = NSString.alloc.initWithUTF8String(str);
    free(str);

    return out_;
}

///Identity. Always return the object itself if it inherits from NSObject
T ns(T)(T value) if(is(T : NSObject)){return value;}

NSMutableDictionaryD!(K, V) ns(K, V)(V[K] aa){return NSMutableDictionaryD!(K, V)(aa);}

NSNumberD!T ns(T)(T value) if(isValidObjectiveCNumber!T)
{
    return NSNumberD!T(value);
}

///Unused since the change to extern(C++)
To nscast(To, From)(From arg)
{
    return (cast(To)cast(void*)arg);
}
////End ns Helper Section////



@ObjectiveC final extern(C++):
@nogc nothrow:

alias BOOL = bool;
enum YES = true;
enum NO = false;

///Type used to represent elapsed time in seconds.
alias CFTimeInterval = double;
alias NSTimeInterval = double;

version(watchOS)
{
    alias NSUInteger = uint;
    alias NSInteger = int;
} 
else
{
    alias NSInteger = long;
    alias NSUInteger = ulong;
}
alias OSStatus = int;
alias OSType = uint;
class NSObject
{
@nogc nothrow:
    static NSObject alloc() @selector("alloc") @instancetype;
    NSObject initialize() @selector("init") @instancetype;
    ///Increments the receiver’s reference count.
    NSObject retain() @selector("retain");
    ///Allocates a new instance of the receiving class, sends it an init message, and returns the initialized object.
    NSObject new_() @selector("new");
    ///Decrements the receiver’s reference count.
    void release() @selector("release");
    ///Deallocates the memory occupied by the receiver.
    void dealloc() @selector("dealloc");
    ///Decrements the receiver’s retain count at the end of the current autorelease pool block.
    NSObject autorelease() @selector("autorelease");

}

///A simple container for a single C or Objective-C data item.
class NSValue
{
@nogc nothrow:
    mixin ObjcExtend!NSObject;
}

///An object wrapper for primitive scalar numeric values.
class NSNumber
{
@nogc nothrow:
    mixin ObjcExtend!NSValue;
    @selector("numberWithBool:") static NSNumber opCall(BOOL);
    @selector("numberWithChar:") static NSNumber opCall(byte);
    @selector("numberWithDouble:") static NSNumber opCall(double);
    @selector("numberWithFloat:") static NSNumber opCall(float);
    @selector("numberWithInt:") static NSNumber opCall(int);
    @selector("numberWithLongLong:") static NSNumber opCall(long);
    @selector("numberWithShort:") static NSNumber opCall(short);
    @selector("numberWithUnsignedChar:") static NSNumber opCall(ubyte);
    @selector("numberWithUnsignedInt:") static NSNumber opCall(uint);
    @selector("numberWithUnsignedLongLong:") static NSNumber opCall(ulong);
    @selector("numberWithUnsignedShort:") static NSNumber opCall(ushort);

    @selector("boolValue") BOOL boolValue();
    @selector("charValue") byte charValue();
    @selector("doubleValue") double doubleValue();
    @selector("floatValue") float floatValue();
    @selector("intValue") int intValue();
    @selector("longLongValue") long longValue();
    @selector("shortValue") short shortValue();
    @selector("unsignedCharValue") ubyte ubyteValue();
    @selector("unsignedIntValue") uint uintValue();
    @selector("unsignedLongLongValue") ulong ulongValue();
    @selector("unsignedShortValue") ushort ushortValue();
}
struct NSNumberD(T) if(isValidObjectiveCNumber!T)
{
    NSNumber num;
    this(T t){num = NSNumber(t);}
    alias num this;
}

extern(C) void NSLog(NSString str, ...);

class NSString
{
@nogc nothrow:
    static NSString alloc() @selector("alloc");
    NSString initWithUTF8String(const(char)* str) @selector("initWithUTF8String:");

    @selector("stringWithCString:encoding:")
    static NSString stringWithCString(const(char)* stringWithCString, size_t encoding);

    ///Returns a string created by copying the data from a given C array of UTF8-encoded bytes.
    @selector("stringWithUTF8String:")
    static NSString stringWithUTF8String(const(char)* nullTerminatedCString);

    ///A null-terminated UTF8 representation of the string.
    @selector("UTF8String")
    const(char)* UTF8String() @nogc const;


    @selector("defaultCStringEncoding")
    static NSUInteger defaultCStringEncoding();
    void release() @selector("release");

    extern(D) final string toString() @nogc const
    {
        const(char)* ret = UTF8String();
        if(ret == null)
            return null;
        size_t i = 0; while(ret[i++] != '\0'){}
        if(i > 0) return cast(string)ret[0..i-1];
        return null;
    }
}

class NSArray
{
@nogc nothrow:
    mixin ObjcExtend!NSObject;
    NSArray init() @selector("init");
    ///Creates and returns an empty array.
    @selector("array")
    static NSArray array();

    ///Creates and returns an array containing the objects in another given array.
    @selector("arrayWithArray:")
    static NSArray array(NSArray array);

    ///Creates and returns an array containing a given object.
    @selector("arrayWithObject:")
    static NSArray array(NSObject object);  

    ///Creates and returns an array containing the objects in the argument list.
    @selector("arrayWithObjects:")
    static NSArray array(NSObject objects, ...);

    ///Creates and returns an array that includes a given number of objects from a given C array.
    @selector("arrayWithObjects:count:")
    static NSArray array(NSObject* objects, NSUInteger count); 

    ///The number of objects in the array.
    @selector("count")
    NSUInteger count();
    alias length = count;

    ///Returns the object located at the specified index.
    @selector("objectAtIndex:")
    NSObject objectAtIndex(NSUInteger index);
}

alias NSArray_(T) = NSArray;

extern(D) struct NSArrayD(T)
{
    NSArray arr = void;
    alias arr this;

    @nogc nothrow
    auto opAssign(NSArray arr)
    {
        this.arr = arr;
        return this;
    }

    @nogc nothrow
    extern(D) pragma(inline, true) T opIndex(size_t index)
    {
        return cast(T)cast(void*)arr.objectAtIndex(index);
    }

    extern(D) int opApply(scope int delegate(T) dg)
    {
        int result = 0;
        NSUInteger l = arr.count;
        for(int i = 0; i < l; i++)
        {
            T item = opIndex(i);
            result = dg(item);
            if (result)
                break;
        }
        return result;
    }
}

class NSDictionary
{
@nogc nothrow:
    mixin ObjcExtend!NSObject;
    ///Creates an empty dictionary.
    @selector("dictionary")
    static NSDictionary dictionary();

    ///The number of entries in the dictionary.
    @selector("count")
    NSUInteger count();

    ///A new array containing the dictionary’s keys, or an empty array if the dictionary has no entries.
    @selector("allKeys")
    NSArray allKeys();

    ///A new array containing the dictionary’s values, or an empty array if the dictionary has no entries.
    @selector("allValues")
    NSArray allValues();

    ///Returns the value associated with a given key.
    @selector("objectForKey:")
    NSObject objectForKey(NSObject);

    ///Returns the value associated with a given key.
    @selector("valueForKey:")
    NSObject valueForKey(NSString);
}
alias NSDictionary_(Key, Value) = NSDictionary;


///A dynamic collection of objects associated with unique keys.
class NSMutableDictionary
{
@nogc nothrow:
    mixin ObjcExtend!NSDictionary;
    @selector("dictionary")
    static NSMutableDictionary dictionary();

    ///Creates and returns a mutable dictionary, initially giving it enough allocated memory to hold a given number of entries.
    @selector("dictionaryWithCapacity:")
    static NSMutableDictionary dictionaryWithCapacity(NSUInteger);

    ///Adds a given key-value pair to the dictionary.
    @selector("setObject:forKey:")
    void setObject(NSObject, NSObject);

    ///Adds a given key-value pair to the dictionary.
    @selector("setValue:forKey:")
    void setValue(NSObject, NSString);
}

extern(D) struct NSMutableDictionaryD(Key, Value) {
@nogc nothrow:
    static if(isValidObjectiveCNumber!Value)
        alias RealValue = NSNumber;
    else static if(is(Value == string))
        alias RealValue = NSString;
    else
    {
        static assert(is(Value : NSObject), "Unknown object of type " ~ Value.stringof ~ " received.");
        alias RealValue = Value;
    }

    NSMutableDictionary dictionary;
    this(NSMutableDictionary d){dictionary = d;}
    this(scope Value[Key] kv)
    {
        dictionary = NSMutableDictionary.dictionaryWithCapacity(32);
        foreach(key, value; kv)
            opIndexAssign(value, key);
    }

    void opIndexAssign(Value v, Key k)
    {
        static if(is(Key == string) || is(Key == NSString))
            dictionary.setValue(cast(NSObject)cast(void*)v.ns, k.ns);
        else
            dictionary.setObject(cast(NSObject)cast(void*)v.ns, k.ns);
    }

    RealValue opIndex(Key k)
    {
        static if(is(Key == string) || is(Key == NSString))
            return cast(RealValue)cast(void*)dictionary.valueForKey(k.ns);
        else
            return cast(RealValue)cast(void*)dictionary.objectForKey(k.ns);
    }

    alias dictionary this;
}

alias NSErrorDomain = NSString;

class NSError
{
@nogc nothrow:
    ///The error code
    @selector("code")
    NSInteger code();

    ///A string containing the error domain.
    @selector("domain")
    NSErrorDomain domain();


    ///A string containing the localized description of the error.
    @selector("localizedDescription")
    NSString localizedDescription();

    ///An array containing the localized titles of buttons appropriate for displaying in an alert panel.
    @selector("localizedRecoveryOptions")
    NSArray_!NSString _localizedRecoveryOptions();

    extern(D) final string toString(){return localizedDescription.toString;}

    extern(D) final NSArrayD!NSString localizedRecoveryOptions()
    {
        return NSArrayD!NSString(_localizedRecoveryOptions);
    }

    ///A string containing the localized recovery suggestion for the error.
    @selector("localizedRecoverySuggestion")
    NSString localizedRecoverySuggestion();

    ///A string containing the localized explanation of the reason for the error.
    @selector("localizedFailureReason")
    NSString localizedFailureReason();


    extern(D) final void print()
    {
        NSLog("Objective-C Error: %@".ns, this);
    }
}
struct NSRange
{
    NSUInteger length;
    NSUInteger location;
}
class NSData
{
@nogc nothrow:
    mixin ObjcExtend!NSObject;
}

///An object that represents the location of a resource, such as an item on a remote server or the path to a local file.
class NSURL
{
@nogc nothrow:
    mixin ObjcExtend!NSObject;

    ///Creates and returns an NSURL object initialized with a provided URL string.
    @selector("URLWithString:") @instancetype
    static NSURL URLWithString(NSString);

    @selector("initWithString:") @instancetype
    ///Initializes an NSURL object with a provided URL string.
    NSURL initWithString(NSString);

    ///Creates and returns an NSURL object initialized with a base URL and a relative string.
    @selector("URLWithString:relativeToURL:") @instancetype
    static NSURL URLWithString(NSString URLString, NSURL relativeToURL);

    ///Initializes an NSURL object with a base URL and a relative string.
    @selector("initWithString:relativeToURL:") @instancetype 
    NSURL initWithString(NSString URLString, NSURL relativeToURL);

    ///Initializes and returns a newly created NSURL object as a file URL with a specified path.
    @selector("fileURLWithPath:isDirectory:")
    static NSURL *fileURLWithPath(NSString path, BOOL isDirectory);

    ///Initializes a newly created NSURL referencing the local file or directory at path.
    @selector("initFileURLWithPath:isDirectory:") @instancetype 
    NSURL initFileURLWithPath(NSString path, BOOL isDirectory);

    @selector("fileURLWithPath:relativeToURL:")
    static NSURL fileURLWithPath(NSString path, NSURL relativeToURL);

    @selector("initFileURLWithPath:relativeToURL:") @instancetype 
    NSURL initFileURLWithPath(NSString path,NSURL relativeToURL);

    @selector("fileURLWithPath:isDirectory:relativeToURL:")
    static NSURL fileURLWithPath(NSString path, BOOL isDirectory, NSURL relativeToURL);

    @selector("initFileURLWithPath:isDirectory:relativeToURL:") @instancetype 
    NSURL initFileURLWithPath(NSString path, BOOL isDirectory, NSURL relativeToURL);

    ///Initializes and returns a newly created NSURL object as a file URL with a specified path.
    @selector("fileURLWithPath:")
    static NSURL fileURLWithPath(NSString);

    ///Initializes a newly created NSURL referencing the local file or directory at path.
    @selector("initFileURLWithPath:") @instancetype 
    NSURL initFileURLWithPath(NSString);


    ///Initializes and returns a newly created NSURL object as a file URL with specified path components.
    @selector("fileURLWithPathComponents:")
    static NSURL fileURLWithPathComponents(NSArray_!NSString components);

    ///The URL string for the receiver as an absolute URL. (read-only)
	@selector("absoluteString")
	NSString absoluteString();

    ///The path, conforming to RFC 1808. (read-only)
    @selector("path")
    NSString path();

    ///An array containing the path components. (read-only)
    @selector("pathComponents")
    NSArray_!NSString pathComponents();

    ///The path extension. (read-only)
    @selector("pathExtension")
    NSString pathExtension();

    ///The relative path, conforming to RFC 1808. (read-only)
    @selector("relativePath")
    NSString relativePath();

    ///A string representation of the relative portion of the URL. (read-only)
    @selector("relativeString")
    NSString relativeString();

    ///The scheme. (read-only)
    @selector("scheme")
    NSString scheme();

    ///A copy of the URL with any instances of ".." or "." removed from its path. (read-only)
    @selector("standardizedURL")
    NSString standardizedURL();

    ///The user name, conforming to RFC 1808.
    @selector("user")
    NSString user();




}

///This defines the structure used as contextual information in the NSFastEnumeration protocol.
struct NSFastEnumerationState
{
@nogc nothrow:
    import core.stdc.config;
    ///A C array that you can use to hold returned values.
    c_ulong[5] extra;
    ///A C array of objects.
    void* itemsPtr;
    ///Arbitrary state information used to detect whether the collection has been mutated.
    c_ulong mutationsPtr;
    ///Arbitrary state information used by the iterator. Typically this is set to 0 at the beginning of the iteration.
    c_ulong state;
}
///A protocol that objects adopt to support fast enumeration.
interface NSFastEnumeration
{
@nogc nothrow:
    ///Returns by reference a C array of objects over which the sender should iterate, and as the return value the number of objects in the array.
    @selector("countByEnumeratingWithState:objects:count:")
    NSUInteger countByEnumeratingWithState(NSFastEnumerationState* state, void* objects, NSUInteger count);
}