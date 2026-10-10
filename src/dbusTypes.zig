//! D-Bus type wrappers used to be recognized
//! by D-Bus functions as special D-Bus types.
//!
//! Implements almost every type in accordance to the specification:
//!
//! https://dbus.freedesktop.org/doc/dbus-specification.html#container-types

/// Creates a Property representation of a D-Bus interface.
pub fn Prop(comptime V: type, comptime mode: enum { Read, Write, ReadWrite }) type {
    return struct {
        value: V,

        pub const Type = V;
        pub const MODE = mode;
        pub const __IS_DBUS_PROP__ = true;

        pub fn init(value: V) V {
            return .{ .value = value };
        }
    };
}
pub fn isProp(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_PROP__");
}

/// Creates a Signal representation of D-Bus interface.
pub fn Signal() type {
    return struct {
        pub const __IS_DBUS_SIGNAL__ = true;

        pub fn init() @This() {
            return .{};
        }
    };
}
pub fn isSignal(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_SIGNAL__");
}

/// Creates a Method representation of a D-Bus interface.
pub fn Method(comptime Callback: type) type {
    return struct {
        callback: Callback,

        pub const __IS_DBUS_METHOD__ = true;

        pub fn init(callback: Callback) @This() {
            return .{ .callback = callback };
        }
    };
}
pub fn isMethod(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_METHOD__");
}

pub const String = [:0]const u8;

pub const ObjectPath = struct {
    path: [:0]const u8,

    pub fn init(path: [:0]const u8) @This() {
        return .{ .path = path };
    }
};

/// Creates a Variant D-Bus type representation.
///
/// `T` is a union-type of the Variant.
pub fn Variant(comptime T: type) type {
    return struct {
        value: T,

        pub const TYPE = T;
        pub const __IS_DBUS_VARIANT__ = true;

        pub fn init(value: T) @This() {
            return .{ .value = value };
        }
    };
}
pub fn isVariant(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_VARIANT__");
}

/// Returns a D-Bus struct, created from struct `T`.
pub fn Struct(comptime T: type) type {
    return struct {
        value: T,

        pub const TYPE = T;
        pub const __IS_DBUS_STRUCT__ = true;

        pub fn init(value: T) @This() {
            return .{ .value = value };
        }
    };
}
pub fn isStruct(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_STRUCT__");
}

/// Returns a D-Bus array with element type `E`.
pub fn Array(comptime E: type) type {
    return struct {
        array: []const E,

        pub const Element = E;
        pub const __IS_DBUS_ARRAY__ = true;

        pub fn init(array: []const E) @This() {
            return .{ .array = array };
        }
    };
}
pub fn isArray(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_ARRAY__");
}

/// Returns a D-Bus dict entry with key type `K` and value type `V`.
pub fn DictEntry(comptime K: type, comptime V: type) type {
    return struct {
        entry: struct { K, V },

        pub const Key = K;
        pub const Value = V;
        pub const __IS_DBUS_DICT_ENTRY__ = true;

        pub fn init(entry: struct { K, V }) @This() {
            return .{ .entry = entry };
        }
    };
}
pub fn isDictEntry(comptime T: type) bool {
    return @hasField(T, "__IS_DBUS_DICT_ENTRY__");
}
