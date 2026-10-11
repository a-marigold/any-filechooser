//! Library-independent D-Bus API.

const std = @import("std");
const Type = std.lang.Type;
const mem = std.mem;
const Io = std.Io;
const process = std.process;
const libdbus = @import("libdbus");
const types = @import("dbusTypes.zig");

const USER_SESSION_BUS_TYPE = libdbus.DBUS_BUS_SESSION;

const G_DBUS_PROPERTY_INFO_FLAGS_READABLE = libdbus.Gio.DBusPropertyInfoFlags.G_DBUS_PROPERTY_INFO_FLAGS_READABLE;
const G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE = libdbus.Gio.DBusPropertyInfoFlags.G_DBUS_PROPERTY_INFO_FLAGS_WRITABLE;

const G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE = libdbus.BusNameOwnerFlags.G_BUS_NAME_OWNER_FLAGS_DO_NOT_QUEUE;

const STATIC_REF_COUNT = -1;

/// D-Bus connection.
pub const Conn = struct {
    conn: *libdbus.DBusConnection,

    const InitError = error{InitFail};
    /// Initializes a connection to a user session D-Bus.
    pub inline fn init() InitError!@This() {
        var connErr: DBusError = .init();

        const conn = libdbus.dbus_bus_get(USER_SESSION_BUS_TYPE, connErr.getPtr());

        if (conn == null) return InitError.InitFail;

        if (connErr.isSet()) {
            connErr.deinit();
            return InitError.InitFail;
        }

        return .{ .conn = conn.? };
    }

    const RequestNameError = error{ RequestNameFail, NameAlreadyTaken };
    /// Requests the D-Bus for a well-known name.
    ///
    /// Returns an error if `name` is already taken by another server.
    pub fn requestName(self: *@This(), name: [:0]const u8) void {
        var nameErr: DBusError = .init();

        const nameCode = libdbus.dbus_bus_request_name(
            self.conn,
            name,
            libdbus.DBUS_NAME_FLAG_DO_NOT_QUEUE,
            nameErr.getPtr(),
        );

        if (nameErr.isSet()) return RequestNameError.RequestNameFail;

        if (nameCode == libdbus.DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER)
            return RequestNameError.NameAlreadyTaken;
    }

    const RegisterObjectError = error{RegisterFail};
    /// Registers `objectPath` and `Interface` at that path.
    ///
    /// Fields of `Interface` struct can be:
    /// - `types.Prop`
    /// - `types.Signal`
    /// - `types.Method`
    ///
    /// If a field of `Interface` struct isn't
    /// the one above types, a compile error is triggerred.
    ///
    /// Declarations of `Interface` are ignored.
    pub fn registerSingleton(
        self: *@This(),
        objectPath: [:0]const u8,
        comptime interface: types.Interface,
    ) RegisterObjectError!void {
        const objectId = libdbus.g_dbus_connection_register_object(
            self.conn,
            objectPath,
            interface,
            null,
            null,
            null,
            null,
        );

        if (objectId == 0) return RegisterObjectError.RegisterFail;
    }
};

/// Returns a D-Bus signature string.
///
/// `T` must be one of types from `dbusTypes` module
/// (primitives like `bool` and `u64` are passes as-is).
///
/// See - https://dbus.freedesktop.org/doc/dbus-specification.html#basic-types
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
        types.String => "s",
        types.ObjectPath => "o",
        else => block: {
            if (types.isVariant(T)) break :block "v";
            if (types.isArray(T)) {
                break :block "a" ++ comptime signatureFromType(@field(T, "Element"));
            }
            if (types.isStruct(T)) {
                var signature: []const u8 = "(";

                const TInfo: Type.Struct = @typeInfo(@field(T, "TYPE"));

                inline for (TInfo.field_types) |fieldType| {
                    signature = signature ++ signatureFromType(fieldType);
                }

                signature = signature ++ ")";

                break :block signature;
            }
            if (types.isDictEntry(T)) {
                const Key = @field(T, "Key");
                const Value = @field(T, "Value");

                break :block comptime "{" ++ signatureFromType(Key) ++ signatureFromType(Value);
            }
        },
    };
}

const DBusError = struct {
    err: LibdbusError,

    /// `DBusError` from `libdbus` has bit fields,
    /// so C translation declares it as opaque type.
    const LibdbusError = packed struct {
        name: usize,
        message: usize,
        _dummy: u5,
        _padding: usize,
    };

    pub inline fn init() @This() {
        var err: LibdbusError = undefined;
        libdbus.dbus_error_init(@ptrCast(&err));

        return .{ .err = err };
    }

    /// Returns a pointer to the error to be passed to `libdbus` fucntions.
    pub inline fn getPtr(self: *@This()) *libdbus.DBusError {
        return @ptrCast(@constCast(&self.err));
    }

    pub inline fn isSet(self: *@This()) bool {
        return libdbus.dbus_error_is_set(@ptrCast(@constCast(&self.err))) != 0;
    }

    /// Should be called only if an error is set.
    pub inline fn deinit(self: *@This()) void {
        libdbus.dbus_error_free(@ptrCast(@constCast(&self.err)));
    }
};
