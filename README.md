# D-objective-c
Repository used to keep a compatible Objective-C bindings generation with D.

## Objective-C strings

```d
NSLog("abcd".ns);
```
## Objective-C Number
```d
5.ns
```

## Objective-C Blocks

Thanks to @jacob-carlborg, we now have support to passing D delegates to Objective-C code.
For further information, [this was supposed to be located in the D runtime](https://github.com/dlang/druntime/pull/1582), but it didn't made unfortunately. Nevertheless, it was a great project and further makes this binding possible!
```d
extern(C) void foo(Block!()* block);
void main()
{
    // The `block` function is used to initialize an instance of `Block`.
    // A delegate will be passed to the `block` function which will be the
    // body of the block.
    auto b = block({ writeln("foo"); });
    foo(&b);
}
```



## Creating Objective-C dictionaries in D
```d
NSMutableDictionaryD a = ["hello": 5].ns;
```
