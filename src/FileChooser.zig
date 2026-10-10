const types = @import("dbusTypes.zig");

version: types.Prop(u32, .Read) = types.Prop(u32, .Read).init(4),

OpenFile: types.Method(@TypeOf(openFile)) = types.Method(@TypeOf(openFile)).init(openFile),
SaveFile: types.Method(@TypeOf(saveFile)) = types.Method(@TypeOf(saveFile)).init(saveFile),
SaveFiles: types.Method(@TypeOf(saveFiles)) = types.Method(@TypeOf(saveFiles)).init(saveFiles),

pub const OBJECT_PATH = "/org/freedesktop/portal/desktop";
pub const INTERFACE_NAME = "org.freedesktop.impl.portal.FileChooser";
pub const BUS_NAME = "org.freedesktop.impl.portal.desktop.any-filechooser";

fn openFile() void {}

fn saveFile() void {}

fn saveFiles() void {}
