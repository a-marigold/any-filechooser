//! Library-independent D-Bus API.

const std = @import("std");
const mem = std.mem;
const Io = std.Io;
const process = std.process;
const goose = @import("goose");

/// D-Bus connection.
pub const Conn = struct {
    inner: goose.Connection,

    /// Initializes a connection to the session D-Bus.
    pub fn init(allocator: mem.Allocator, io: Io, env: process.Environ.Map) !@This() {
        return .{ .inner = .init(allocator, .Session, io, env) };
    }
    /// Requests the D-Bus for an unique bus `name`.
    pub fn requestBusName(self: *@This(), name: [:0]const u8) !void {
        return self.inner.requestName(name);
    }
    /// Registers interface of type `T` with `name` at `objectPath`.
    // TODO: `T` interface documentation
    pub fn registerInterface(self: *@This(), comptime T: type, name: [:0]const u8, objectPath: [:0]const u8) !void {
        return self.inner.registerObject(T, name, objectPath, {});
    }
};
