//! Library-independent D-Bus API.

const std = @import("std");
const Type = std.lang.Type;
const mem = std.mem;
const Io = std.Io;
const process = std.process;
const posix = std.posix;
const libdbus = @import("libdbus");
const Epoll = @import("Epoll.zig");
const types = @import("dbusTypes.zig");

const USER_SESSION_BUS_TYPE = libdbus.DBUS_BUS_SESSION;

/// D-Bus connection.
pub const Conn = struct {
    conn: *libdbus.DBusConnection,

    const InitError = error{InitFail};
    /// Initializes a connection to a user session D-Bus.
    pub inline fn init() InitError!@This() {
        var connErr: LibdbusError = .init();

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
    pub fn requestName(self: @This(), name: [:0]const u8) RequestNameError!void {
        var nameErr: LibdbusError = .init();

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

    /// Returns file descriptor of the opened D-Bus connection socket.
    ///
    /// The socket is always non-blocking.
    pub fn getSocketFd(self: @This()) posix.fd_t {
        var fd: posix.fd_t = undefined;

        _ = libdbus.dbus_connection_get_unix_fd(self.conn, &fd);

        return fd;
    }
};

/// D-Bus message to send or to receive.
pub const Message = struct {
    message: *libdbus.DBusMessage,

    pub const Types = enum(i32) {
        pub const METHOD_CALL = libdbus.DBUS_MESSAGE_TYPE_METHOD_CALL;
        pub const METHOD_RETURN = libdbus.DBUS_MESSAGE_TYPE_METHOD_RETURN;
        pub const ERROR = libdbus.DBUS_MESSAGE_TYPE_ERROR;
        pub const SIGNAL = libdbus.DBUS_MESSAGE_TYPE_SIGNAL;
    };

    /// Returns one of declarations of `Types` or any other unknown value.
    ///
    /// If an unknown value is returned, it should be ignored.
    pub inline fn getType(self: @This()) i32 {
        const messageType = libdbus.dbus_message_get_type(self.message);

        return @fromBackingInt(messageType);
    }

    /// Returns object path of the message or `null` if no specified.
    pub inline fn getObjectPath(self: @This()) ?[]const u8 {
        return if (libdbus.dbus_message_get_path(self.message)) |objectPath|
            mem.span(objectPath)
        else
            null;
    }

    /// Returns interface name of the message or `null` if no specified.
    pub inline fn getInterfaceName(self: @This()) ?[]const u8 {
        return if (libdbus.dbus_message_get_interface(self.message)) |interfaceName|
            mem.span(interfaceName)
        else
            null;
    }
};

/// Internal `libdbus` error.
const LibdbusError = struct {
    err: DBusError,

    /// `DBusError` from `libdbus` has bit fields,
    /// so C translation declares it as opaque type.
    const DBusError = packed struct {
        name: usize,
        message: usize,
        _dummy: u5,
        _padding: usize,
    };

    pub inline fn init() @This() {
        var err: DBusError = undefined;
        libdbus.dbus_error_init(@ptrCast(&err));

        return .{ .err = err };
    }

    /// Returns a pointer to the error to be passed to `libdbus` functions.
    pub inline fn getPtr(self: *@This()) *libdbus.DBusError {
        return @ptrCast(@constCast(&self.err));
    }

    pub inline fn isSet(self: *@This()) bool {
        return libdbus.dbus_error_is_set(@ptrCast(@constCast(&self.err))) != 0;
    }

    /// Should be called only if an error is set,
    /// otherwise there is nothing to deinitialize.
    pub inline fn deinit(self: *@This()) void {
        libdbus.dbus_error_free(@ptrCast(@constCast(&self.err)));
    }
};

/// Returns a D-Bus signature string.
///
/// `T` must be one of types from `dbusTypes` module
/// (primitives like `bool` and `u64` are passed as-is).
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
