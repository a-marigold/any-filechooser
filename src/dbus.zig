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
    busNameId: glib.guint,

    const InitError = error{InitFail};
    /// Initializes a connection to a user session D-Bus.
    pub inline fn init() InitError!@This() {
        const conn = glib.g_bus_get_sync(USER_SESSION_BUS_TYPE, null, null);

        if (conn == null) return InitError.InitFail;

        return .{ .conn = conn.?, .busNameId = undefined };
    }
};
