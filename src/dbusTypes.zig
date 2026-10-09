const std = @import("std");
const Type = std.lang.Type;

/// Creates a Property representation of a D-Bus interface.
///
/// Used to be recognized by D-Bus functions as an interface property.
pub fn Prop(comptime V: type, comptime mode: enum { Read, Write, ReadWrite }) type {
    return struct {
        value: V,
        pub const MODE = mode;

        pub const __IS_DBUS_PROP__ = true;
    };
}
pub fn isProp(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_PROP__");
}

/// Creates a Signal representation of D-Bus interface.
///
/// Used to be recognized by D-Bus functions as an interface signal.
pub fn Signal() type {
    return struct {
        pub const __IS_DBUS_SIGNAL__ = true;
    };
}
pub fn isSignal(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_SIGNAL__");
}

/// Creates a Method representation of a D-Bus interface.
///
/// Used to be recognized by D-Bus functions as an interface method.
pub fn Method(comptime Callback: type) type {
    return struct {
        callback: Callback,

        pub const __IS_DBUS_METHOD__ = true;
    };
}
pub fn isMethod(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_METHOD__");
}

const ObjectPath = struct { path: [:0]const u8 };
/// Does nothing but creates a distinct type (`ObjectPath`) instance
/// to be recognized by as an object path and not a plain string in D-Bus functions.
pub fn getObjectPath(path: [:0]const u8) ObjectPath {
    return .{ .path = path };
}
