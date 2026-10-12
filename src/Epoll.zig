const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

fd: posix.fd_t,

pub const InitError = error{CreateEpollFail};
pub inline fn init() InitError!@This() {
    const fd = linux.epoll_create1(0);

    if (fd == -1) return InitError.CreateEpollFail;

    return .{ .fd = fd };
}

pub const AddFdError = error{AddFdFail};
pub inline fn addFd(self: @This(), fd: posix.fd_t, event: *Event) AddFdError!void {
    const addResult = linux.epoll_ctl(
        self.fd,
        linux.EPOLL.CTL_ADD,
        fd,
        event,
    );

    if (addResult == -1) return AddFdError.AddFdFail;
}

pub const INFINITY_TIMEOUT = -1;
/// If passed to `wait` functions,
/// they don't block if there is a ready event.
pub const NON_BLOCK_TIMEOUT = 0;

pub const WaitError = error{ Timeout, Interrupt, Unexpected };

pub inline fn waitOne(self: @This(), timeout: i32) WaitError!Event {
    var events: [1]linux.epoll_event = undefined;

    const waitResult = linux.epoll_wait(self.fd, &events, events.len, timeout);

    if (waitResult == 0) {
        @branchHint(.unlikely);

        return WaitError.Timeout;
    } else if (waitResult == -1) {
        @branchHint(.unlikely);

        return switch (linux.errno(waitResult)) {
            linux.E.INTR => WaitError.Interrupt,
            else => WaitError.Unexpected,
        };
    }

    return .wrap(events[0]);
}

/// Epoll event for a file descriptor.
pub const Event = struct {
    event: linux.epoll_event,

    pub const Type = enum(comptime_int) {
        In = linux.EPOLL.IN,
        Out = linux.EPOLL.OUT,
        EdgeTriggered = linux.EPOLL.ET,
    };

    pub inline fn init(
        /// Array of `Type` enum.
        comptime eventTypes: []const Type,
        data: linux.epoll_data,
    ) @This() {
        const eventTypesMask = block: {
            var mask: u32 = 0;
            inline for (eventTypes) |eventType| {
                mask |= eventType;
            }

            break :block mask;
        };

        return .{
            .event = .{
                .events = eventTypesMask,
                .data = data,
            },
        };
    }

    /// Wrap an existing event.
    pub inline fn wrap(event: linux.epoll_event) @This() {
        return .{ .event = event };
    }
};
