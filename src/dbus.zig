//! Library-independent D-Bus API.

const std = @import("std");
const Type = std.lang.Type;
const mem = std.mem;
const Io = std.Io;
const process = std.process;
const glib = @import("glib");
const types = @import("dbusTypes.zig");

const USER_SESSION_BUS_TYPE = glib.BusType.G_BUS_TYPE_SESSION;

const G_DBUS_PROPERTY_INFO_FLAGS_READABLE = glib.Gio.DBusPropertyInfoFlags.G_DBUS_PROPERTY_INFO_FLAGS_READABLE;
const G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE = glib.Gio.DBusPropertyInfoFlags.G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE;

const G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE = glib.BusNameOwnerFlags.G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE;

const STATIC_REF_COUNT = -1;

/// D-Bus connection.
pub const Conn = struct {
    conn: *glib.GDBusConnection,

    const InitError = error{InitFail};
    /// Initializes a connection to a user session D-Bus.
    pub inline fn init() InitError!@This() {
        const conn = glib.g_bus_get_sync(USER_SESSION_BUS_TYPE, null, null);

        if (conn == null) return InitError.InitFail;

        return .{ .conn = conn.?, .busNameId = undefined };
    }

    const BusName = struct { id: glib.guint };
    /// Requests the D-Bus for an unique bus `name`.
    ///
    /// Returns `BusName` to allow manual unowning `name`.
    pub fn requestBusName(self: *@This(), name: [:0]const u8) BusName {
        return .{
            .id = glib.g_bus_own_name_on_connection(
                self.conn,
                name,
                G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE,
                null,
                null,
                null,
                null,
                null,
            ),
        };
    }
};
/// Returns a string corresponding to a type `T` in accordance to the specification:
///
/// https://dbus.freedesktop.org/doc/dbus-specification.html#basic-types
pub fn signatureFromType(comptime T: type) []const u8 {
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
        types.ObjectPath => "o",
    };
}

/// Counts quantity of properties, singals
/// and methods of a D-Bus interface of type `T`.
///
/// Triggers a compile error if `T` fields contain anything expect `Prop`, `Signal` and `Method`.
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
        if (types.isProp(fieldType)) {
            propCount += 1;
        } else if (types.isSignal(fieldType)) {
            signalCount += 1;
        } else if (types.isMethod(fieldType)) {
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
        if (types.isProp(fieldType)) {
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
        } else if (types.isSignal(fieldType)) {
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
