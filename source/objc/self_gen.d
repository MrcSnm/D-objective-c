module objc.self_gen;
import objc.meta;
import objc.runtime;

mixin ObjcLinkModule!(objc.runtime);
mixin ObjcInitSelectors!(__traits(parent, {}));