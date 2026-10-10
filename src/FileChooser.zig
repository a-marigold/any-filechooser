const types = @import("dbusTypes.zig");

version: types.Prop(u32, .Read) = types.Prop(u32, .Read).init(4),

OpenFile: types.Method(@TypeOf(openFile)) = types.Method(@TypeOf(openFile)).init(openFile),
SaveFile: types.Method(@TypeOf(saveFile)) = types.Method(@TypeOf(saveFile)).init(saveFile),
SaveFiles: types.Method(@TypeOf(saveFiles)) = types.Method(@TypeOf(saveFiles)).init(saveFiles),

fn openFile() void {}

fn saveFile() void {}

fn saveFiles() void {}
