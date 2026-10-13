const std = @import("std");
const linux = std.os.linux;

fd: linux.fd_t,

pub const InitError = error{CreateEpollFail};
pub inline fn init() InitError!@This() {
    const fd = linux.epoll_create1(0);

    if (fd == -1) return InitError.CreateEpollFail;

    return .{ .fd = fd };
}

pub const AddFdError = error{AddFdFail};
/// Adds `fd` and its `event` to the epoll context.
pub inline fn addFd(self: @This(), fd: linux.fd_t, event: *Event) AddFdError!void {
    const addResult = linux.epoll_ctl(
        self.fd,
        linux.EPOLL.CTL_ADD,
        fd,
        event,
    );

    if (addResult == -1) return AddFdError.AddFdFail;
}

pub const Timeouts = struct {
    pub const INFINITY = -1;

    /// If passed to `wait` functions,
    /// they don't block if there is a ready event.
    pub const NON_BLOCK = 0;
};

pub const WaitError = error{ Timeout, Interrupt, Unexpected };

/// Waits for file descriptors, writes ready events of them to `events`,
/// and returns a slice of `events`, length of which is the amount of ready events.
pub inline fn wait(self: @This(), timeout: i32, events: []linux.epoll_event) WaitError![]linux.epoll_event {
    const readyEventsLen = linux.epoll_wait(
        self.fd,
        events,
        events.len,
        timeout,
    );

    if (readyEventsLen == 0)
        return WaitError.Timeout
    else if (readyEventsLen == -1)
        return switch (linux.errno(readyEventsLen)) {
            linux.E.INTR => WaitError.Interrupt,
            else => WaitError.Unexpected,
        };

    return events[0..readyEventsLen];
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

    /// Wrap an existing event's low-level struct.
    pub inline fn wrap(event: linux.epoll_event) @This() {
        return .{ .event = event };
    }
};
