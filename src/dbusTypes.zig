const std = @import("std");
const Type = std.lang.Type;
const glib = @import("glib");

const STATIC_REF_COUNT = -1;

const G_DBUS_PROPERTY_INFO_FLAGS_READABLE = glib.Gio.DBusPropertyInfoFlags.G_DBUS_PROPERTY_INFO_FLAGS_READABLE;
const G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE = glib.Gio.DBusPropertyInfoFlags.G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE;

/// Creates a Property representation of a D-Bus interface.
///
/// Used to be recognized by D-Bus functions as an interface property.
pub fn Prop(comptime V: type, comptime mode: enum { Read, Write, ReadWrite }) type {
    return struct {
        pub const Value = V;
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

/// Returns a string corresponding to a type `T` in accordance to the specification:
///
/// https://dbus.freedesktop.org/doc/dbus-specification.html#basic-types
fn signatureFromType(comptime T: type) []const u8 {
    return switch (T) {
        i16 => "n",
        i32 => "i",
        i64 => "x",
        u8 => "y",
        u16 => "q",
        u32 => "u",
        u64 => "t",
        f64 => "d",

        bool => "b",

        []const u8 => "s",

        ObjectPath => "o",
    };
}

/// Counts quantity of properties, singals
/// and methods of a D-Bus interface of type `T`.
///
/// Shows a compile error if `T` fields contain anything expect `Prop`, `Signal` and `Method`.
///
/// Used for static allocations.
pub fn countInterfaceFields(comptime T: type) struct {
    props: comptime_int,
    signals: comptime_int,
    methods: comptime_int,
} {
    const TInfo: Type.Struct = @typeInfo(T).@"struct";

    var propCount = 0;
    var signalCount = 0;
    var methodCount = 0;

    inline for (TInfo.field_types) |fieldType|
        if (isProp(fieldType)) {
            propCount += 1;
        } else if (isSignal(fieldType)) {
            signalCount += 1;
        } else if (isMethod(fieldType)) {
            methodCount += 1;
        } else @compileError("Interface field can only be a Property, Signal or Method");

    return .{
        .props = propCount,
        .signals = signalCount,
        .methods = methodCount,
    };
}

/// Generates interface info and writes it to `output`.
///
/// Allows statically allocated infos.
/// If the info is static, `lifetime` must be `Static`.
fn getInterfaceInfo(
    comptime T: type,
    comptime lifetime: enum(comptime_int) { Static = STATIC_REF_COUNT, Dynamic = 1 },
    output: struct {
        props: *[countInterfaceFields(T).props]glib.GDBusPropertyInfo,
        signals: *[countInterfaceFields(T).signals]glib.GDBusSignalInfo,
        methods: *[countInterfaceFields(T).methods]glib.GDBusMethodInfo,
    },
) void {
    const TInfo: Type.Struct = @typeInfo(T).@"struct";

    // If `lifetime` is `Static`, i.e, -1,
    // GLib treats structs as statically allocated
    const refCount = @intFromEnum(lifetime);

    const props = output.props;
    const signals = output.singlas;
    const methods = output.methods;

    var propIndex = 0;
    var signalIndex = 0;
    var methodIndex = 0;

    inline for (TInfo.field_names, TInfo.field_types) |fieldName, fieldType|
        if (isProp(fieldType)) {
            props[propIndex] = .{
                .ref_count = refCount,
                .name = fieldName,
                .signature = signatureFromType(@field(fieldType, "Value")),
                .flags = switch (@field(fieldType, "MODE")) {
                    .Read => G_DBUS_PROPERTY_INFO_FLAGS_READABLE,
                    .Write => G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE,
                    .ReadWrite => G_DBUS_PROPERTY_INFO_FLAGS_READABLE | G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE,
                },
                .annotations = null,
            };

            propIndex += 1;
        } else if (isSignal(fieldType)) {
            signals[signalIndex] = .{
                .ref_count = refCount,
                .name = fieldName,
                .args = .{},
                .annotations = null,
            };

            signalIndex += 1;
        } else {
            methods[methodIndex] = .{
                .ref_count = refCount,
            };

            methodIndex += 1;
        };
}
