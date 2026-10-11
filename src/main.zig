const std = @import("std");
const process = std.process;

const dbus = @import("dbus.zig");
const types = @import("dbusTypes.zig");
const FileChooser = @import("FileChooser.zig");

pub fn main() void {
    var conn: dbus.Conn = try .init();

    conn.requestBusName(FileChooser.BUS_NAME);

    try conn.registerSingleton(
        FileChooser.OBJECT_PATH,
        FileChooser,
        FileChooser.INTERFACE_NAME,
    );
}
